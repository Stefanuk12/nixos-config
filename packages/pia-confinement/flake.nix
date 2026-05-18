{
  description = "PIA WireGuard tunnel confined to a network namespace, with optional per-app service wrappers";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";
    vpn-confinement.url = "github:Maroka-chan/VPN-Confinement";
    pia-manual-connections = {
      url = "github:pia-foss/manual-connections";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      vpn-confinement,
      pia-manual-connections,
    }:
    {
      nixosModules.default =
        { ... }:
        {
          imports = [
            vpn-confinement.nixosModules.default
            (import ./module.nix { piaSrc = pia-manual-connections; })
          ];
        };
      nixosModules.pia-confinement = self.nixosModules.default;
    };
}
