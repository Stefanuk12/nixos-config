{
  description = "yo mother";

  inputs = {
    # Nixpkgs + HyDE
    hydenix.url = "github:Stefanuk12/hydenix";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    nixpkgs.follows = "hydenix/nixpkgs";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    # Home manager
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    # sops
    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";
    bwm.url = "github:firecat53/bitwarden-menu";
    bwm.inputs.nixpkgs.follows = "nixpkgs";

    # Nixvim!!
    Neve.url = "github:redyf/Neve";

    # cool looks
    nix-colors.url = "github:misterio77/nix-colors";

    # VM stuff
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    barely-metal.url = "github:Stefanuk12/BarelyMetal/lg";
    barely-metal.inputs.nixpkgs.follows = "nixpkgs";
    nixvirt.url = "github:Stefanuk12/NixVirt/patch-pulseaudio";
    nixvirt.inputs.nixpkgs.follows = "nixpkgs";

    # Secure Boot
    lanzaboote.url = "github:nix-community/lanzaboote/v1.0.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    # For VPS - Minecraft server
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";

    # Other tools
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    ancs4linux.url = "./packages/ancs4linux";
    ancs4linux.inputs.nixpkgs.follows = "nixpkgs";
    claude-desktop.url = "github:aaddrick/claude-desktop-debian/89208a596a3e876a74f865fb5267996f666f4a09";

    # Gaming
    nix-reshade.url = "github:LovingMelody/nix-reshade";
    nix-reshade.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      hydenix,
      home-manager,
      nix-colors,
      nixvirt,
      nix-minecraft,
      barely-metal,
      nixos-facter-modules,
      ancs4linux,
      claude-desktop,
      nix-reshade,
      ...
    }@inputs:
    let
      inherit (self) outputs;
      systems = [
        "aarch64-linux"
        "i686-linux"
        "x86_64-linux"
        "aarch64-darwin"
        "x86_64-darwin"
      ];
      lib = nixpkgs.lib;
      forAllSystems = lib.genAttrs systems;
    in
    {
      nixosConfigurations = {
        home = lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/home/configuration.nix
            ./secrets
          ];
          specialArgs = {
            inherit inputs;
            hostName = "home";
          };
        };
        vps = lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/vps/configuration.nix
            ./secrets
          ];
          specialArgs = {
            inherit inputs;
            hostName = "vps";
          };
        };
      };
      homeConfigurations = {
        "stefan@home" = home-manager.lib.homeManagerConfiguration {
          pkgs = import nixpkgs {
            system = "x86_64-linux";
            config.allowUnfree = true;
            overlays = [
              claude-desktop.overlays.default
              hydenix.overlays.default
            ];
          };
          modules = [
            ./hosts/home/home.nix
          ];
          extraSpecialArgs = {
            inherit inputs;
            hostName = "home";
            username = "stefan";
          };
        };
        "stefan@vps" = home-manager.lib.homeManagerConfiguration {
          pkgs = nixpkgs.legacyPackages."x86_64-linux";
          modules = [
            ./hosts/vps/home.nix
          ];
          extraSpecialArgs = {
            inherit inputs;
            hostName = "vps";
            username = "stefan";
            system = "x86_64-linux";
          };
        };
      };
    };
}
