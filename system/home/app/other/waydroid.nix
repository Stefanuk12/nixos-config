{ pkgs, ... }:

{
  # Kernel 6.18 (hydenix) ships without legacy xtables modules, but
  # waydroid-net.sh prefers iptables-legacy and has nftables hardcoded
  # off. Flip the flag and bake nft's absolute path in (upstream's
  # wrapProgram PATH doesn't include nftables).
  nixpkgs.overlays = [
    (final: prev: {
      waydroid = prev.waydroid.overrideAttrs (old: {
        postPatch = (old.postPatch or "") + ''
          substituteInPlace data/scripts/waydroid-net.sh \
            --replace-fail 'LXC_USE_NFT="false"' 'LXC_USE_NFT="true"' \
            --replace-fail 'NFT="$(command -v nft)"' 'NFT="${prev.nftables}/bin/nft"' \
            --replace-fail 'nft list ruleset' '${prev.nftables}/bin/nft list ruleset' \
            --replace-fail '    nft "''${NFT_RULESET}"' '    ${prev.nftables}/bin/nft "''${NFT_RULESET}"' \
            --replace-fail \
              'add rule ip lxc postrouting ip saddr ''${LXC_NETWORK} ip daddr != ''${LXC_NETWORK} counter masquerade' \
              'add rule ip lxc postrouting ip saddr ''${LXC_NETWORK} ip daddr != ''${LXC_NETWORK} oifname != "pia-br" counter masquerade'
        '';
      });
    })
  ];

  virtualisation.waydroid.enable = true;

  environment.systemPackages = with pkgs; [
    waydroid-helper
    android-tools
  ];

  # Route Android's bridge traffic through the existing pia netns
  # without putting waydroid-container itself in the netns (Android's
  # LXC init is flaky inside a non-host netns). The wg endpoint lives
  # in the pia netns; we cross into it via vpn-confinement's existing
  # veth pair (pia-br on host <-> veth-pia in pia netns), source-route
  # waydroid0 traffic over it, then NAT out pia0 inside the netns.
  systemd.services.waydroid-pia-route = {
    description = "Source-route Android bridge traffic through pia netns";
    after = [ "pia.service" "waydroid-container.service" ];
    requires = [ "pia.service" ];
    wantedBy = [ "waydroid-container.service" "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
    };
    path = with pkgs; [ iproute2 iptables ];
    script = ''
      set -eu

      # Wait until waydroid0 exists (waydroid-container creates it).
      for _ in $(seq 1 30); do
        ip link show waydroid0 >/dev/null 2>&1 && break
        sleep 1
      done

      # Host side: source-route 192.168.240.0/24 to the pia netns via
      # vpn-confinement's transit bridge (192.168.15.1 = veth-pia inside
      # the netns). Higher-priority rule keeps intra-bridge traffic on
      # the main table — without it, the host's own replies from
      # 192.168.240.1 also match the source-route and get sent through
      # PIA, breaking dnsmasq/DHCP for Android.
      ip route replace default via 192.168.15.1 dev pia-br table 200
      ip rule list | grep -q "to 192.168.240.0/24 lookup main" \
        || ip rule add to 192.168.240.0/24 lookup main priority 50
      ip rule list | grep -q "from 192.168.240.0/24 lookup 200" \
        || ip rule add from 192.168.240.0/24 table 200 priority 100

      # Netns side: route replies for Android back over the transit
      # veth, accept forwarded traffic between veth-pia and pia0, and
      # masquerade Android's source range out the wg interface.
      ip netns exec pia ip route replace 192.168.240.0/24 via 192.168.15.5 dev veth-pia
      ip netns exec pia iptables -C FORWARD -s 192.168.240.0/24 -i veth-pia -o pia0 -j ACCEPT 2>/dev/null \
        || ip netns exec pia iptables -I FORWARD -s 192.168.240.0/24 -i veth-pia -o pia0 -j ACCEPT
      ip netns exec pia iptables -C FORWARD -d 192.168.240.0/24 -i pia0 -o veth-pia -j ACCEPT 2>/dev/null \
        || ip netns exec pia iptables -I FORWARD -d 192.168.240.0/24 -i pia0 -o veth-pia -j ACCEPT
      ip netns exec pia iptables -t nat -C POSTROUTING -s 192.168.240.0/24 -o pia0 -j MASQUERADE 2>/dev/null \
        || ip netns exec pia iptables -t nat -A POSTROUTING -s 192.168.240.0/24 -o pia0 -j MASQUERADE
    '';
  };
}
