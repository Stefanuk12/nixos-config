{
  description = "PlayStation VR2 on SteamVR for Linux: Ignition, PSVR2Toolkit, SteamVRLinuxFixes, play area setup, firmware updater, udev rules";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs, ... }:
    let
      systems = [ "x86_64-linux" ];
      forAllSystems = nixpkgs.lib.genAttrs systems;
      pkgsFor =
        system:
        import nixpkgs {
          inherit system;
          config.allowUnfree = true;
        };
    in
    {
      packages = forAllSystems (system: import ./pkgs { pkgs = pkgsFor system; });

      homeManagerModules = {
        default = ./modules/home-manager.nix;
        psvr2-toolkit = ./modules/home-manager.nix;
      };

      nixosModules = {
        default = ./modules/nixos.nix;
        psvr2 = ./modules/nixos.nix;
      };

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
