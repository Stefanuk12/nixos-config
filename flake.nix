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

    # Nixvim!!
    Neve.url = "github:redyf/Neve";

    # cool looks
    nix-colors.url = "github:misterio77/nix-colors";

    # wm stuff
    hypridle.url = "github:hyprwm/hypridle";

    # VM stuff
    nixos-vfio.url = "github:Stefanuk12/nixos-vfio/patch-1";    
    nixvirt.url = "https://flakehub.com/f/AshleyYakeley/NixVirt/*.tar.gz";
    nixvirt.inputs.nixpkgs.follows = "nixpkgs";

    # Secure Boot
    lanzaboote.url = "github:nix-community/lanzaboote/v0.3.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";
  
    # For VPS - Minecraft server
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";

    # Custom packages
    customPkgs = {
      path = ./customPkgs;
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  nixpkgs.config.allowUnfree = true;
  
  outputs = {
    self,
    nixpkgs,
    home-manager,
    nix-colors,
    nixos-vfio,
    nixvirt,
    nix-minecraft,
    customPkgs,
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
          customPkgs = inputs.customPkgs;
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
          customPkgs = inputs.customPkgs;
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
          customPkgs = inputs.customPkgs;
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
          customPkgs = inputs.customPkgs;
        };
      };
    };
  };
}