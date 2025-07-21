{
  description = "yo mother";

  inputs = {
    # Nixpkgs
    nixpkgs.url = "github:nixos/nixpkgs?ref=nixos-unstable";
  
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
    nixvirt.url = "github:Stefanuk12/NixVirt/patch-pulseaudio";
    nixvirt.inputs.nixpkgs.follows = "nixpkgs";

    # Secure Boot
    lanzaboote.url = "github:nix-community/lanzaboote/v0.4.2";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  
    # For VPS - Minecraft server
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";
  };
  
  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-colors,
    nixvirt,
    nix-minecraft,
    ...
  } @ inputs: let
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
  in {
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
      mail-server = lib.nixosSystem {
        system = "aarch64-linux";
        modules = [
          ./hosts/mail-server/configuration.nix
          ./hosts/mail-server/hardware-configuration.nix
          ./secrets
        ];
        specialArgs = {
          inherit inputs;
          hostName = "mail-server";
        };
      };
    };
    homeConfigurations = {
      "stefan@home" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."x86_64-linux";
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
      "stefan@mail-server" = home-manager.lib.homeManagerConfiguration {
        pkgs = nixpkgs.legacyPackages."aarch64-linux";
        modules = [
          ./hosts/mail-server/home.nix
        ];
        extraSpecialArgs = {
          inherit inputs;
          hostName = "mail-server";
          username = "stefan";
          system = "aarch64-linux";
        };
      };
    };
  };
}
