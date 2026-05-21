{ pkgs, ... }:

let
  androidNet = "192.168.240.0/24";
  androidGw = "192.168.240.1";
  piaBrHost = "192.168.15.5"; # host side of vpn-confinement transit bridge
  piaBrNetns = "192.168.15.1"; # netns side
  rtTable = "200";
in
{
  # Hydenix's 6.18 kernel lacks legacy xtables, but waydroid-net.sh
  # prefers iptables-legacy and hardcodes nftables off. Flip the flag,
  # absolute-path the nft calls (wrapper PATH doesn't include nftables),
  # and scope the host masquerade so it doesn't fire for traffic we're
  # sending into the pia netns.
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

  # Route Android's bridge traffic through the existing pia netns.
  # waydroid-container stays in the host netns (LXC's Android init is
  # flaky inside a non-host netns); we cross into pia via the
  # vpn-confinement transit veth (pia-br <-> veth-pia), source-route
  # waydroid0's subnet over it, then NAT out pia0 inside the netns.
  #
  # The "to <androidNet> lookup main" rule is load-bearing: without
  # it the host's replies from ${androidGw} match the source-route
  # too and get sent through PIA, killing dnsmasq/DHCP for Android.
  systemd.services.waydroid-pia-route = {
    description = "Route Android bridge traffic through pia netns";
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

      for _ in $(seq 1 30); do
        ip link show waydroid0 >/dev/null 2>&1 && break
        sleep 1
      done

      ip route replace default via ${piaBrNetns} dev pia-br table ${rtTable}
      ip rule add to ${androidNet} lookup main priority 50 2>/dev/null || true
      ip rule add from ${androidNet} lookup ${rtTable} priority 100 2>/dev/null || true

      ip netns exec pia ip route replace ${androidNet} via ${piaBrHost} dev veth-pia
      ip netns exec pia iptables -C FORWARD -s ${androidNet} -i veth-pia -o pia0 -j ACCEPT 2>/dev/null \
        || ip netns exec pia iptables -I FORWARD -s ${androidNet} -i veth-pia -o pia0 -j ACCEPT
      ip netns exec pia iptables -C FORWARD -d ${androidNet} -i pia0 -o veth-pia -j ACCEPT 2>/dev/null \
        || ip netns exec pia iptables -I FORWARD -d ${androidNet} -i pia0 -o veth-pia -j ACCEPT
      ip netns exec pia iptables -t nat -C POSTROUTING -s ${androidNet} -o pia0 -j MASQUERADE 2>/dev/null \
        || ip netns exec pia iptables -t nat -A POSTROUTING -s ${androidNet} -o pia0 -j MASQUERADE
    '';
    preStop = ''
      ip rule del to ${androidNet} lookup main priority 50 2>/dev/null || true
      ip rule del from ${androidNet} lookup ${rtTable} priority 100 2>/dev/null || true
      ip route flush table ${rtTable} 2>/dev/null || true
      ip netns exec pia iptables -D FORWARD -s ${androidNet} -i veth-pia -o pia0 -j ACCEPT 2>/dev/null || true
      ip netns exec pia iptables -D FORWARD -d ${androidNet} -i pia0 -o veth-pia -j ACCEPT 2>/dev/null || true
      ip netns exec pia iptables -t nat -D POSTROUTING -s ${androidNet} -o pia0 -j MASQUERADE 2>/dev/null || true
      ip netns exec pia ip route del ${androidNet} via ${piaBrHost} dev veth-pia 2>/dev/null || true
    '';
  };
}
