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
  };
  
  outputs = {
    self,
    nixpkgs,
    home-manager,
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
	specialArgs = { inherit inputs; };
      };
    };
    homeConfigurations = {
      "stefan@home" = home-manager.lib.homeManagerConfiguration {
	pkgs = nixpkgs.legacyPackages."x86_64-linux";
        modules = [
          ./hosts/home/home.nix
        ];
	extraSpecialArgs = { inherit inputs; };
      };
    };
  };
}
