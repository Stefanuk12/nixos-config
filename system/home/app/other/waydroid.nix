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
            --replace-fail '    nft "''${NFT_RULESET}"' '    ${prev.nftables}/bin/nft "''${NFT_RULESET}"'
        '';
      });
    })
  ];

  virtualisation.waydroid.enable = true;

  environment.systemPackages = with pkgs; [
    waydroid-helper
  ];
}
