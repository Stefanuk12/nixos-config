{
  description = "yo mother";

  inputs = {
    # Nixpkgs + HyDE
    hydenix.url = "github:Stefanuk12/hydenix";
    # nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    # nixpkgs.follows = "hydenix/nixpkgs";
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

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

    # VM stuff
    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    barely-metal.url = "github:Stefanuk12/BarelyMetal/update";
    barely-metal.inputs.nixpkgs.follows = "nixpkgs";
    nixvirt.url = "github:Stefanuk12/NixVirt/patch-pulseaudio";
    nixvirt.inputs.nixpkgs.follows = "nixpkgs";
    osx-kvm.url = "./packages/osx-kvm";
    osx-kvm.inputs.nixpkgs.follows = "nixpkgs";

    # Secure Boot
    lanzaboote.url = "github:nix-community/lanzaboote/v1.1.0";
    lanzaboote.inputs.nixpkgs.follows = "nixpkgs";

    # For VPS - Minecraft server
    nix-minecraft.url = "github:Infinidoge/nix-minecraft";
    nix-minecraft.inputs.nixpkgs.follows = "nixpkgs";

    # PIA WireGuard tunnel inside a netns + per-app confinement helpers
    pia-confinement.url = "./packages/pia-confinement";
    pia-confinement.inputs.nixpkgs.follows = "nixpkgs";

    # rbw-based "fetch a Bitwarden entry to a tmpfs file" systemd module
    rbw-fetch.url = "./packages/rbw-fetch";
    rbw-fetch.inputs.nixpkgs.follows = "nixpkgs";

    # Helium browser -- not in nixpkgs yet (PR pending), packaged from the upstream .deb
    helium.url = "github:oxcl/nix-flake-helium-browser";
    helium.inputs.nixpkgs.follows = "nixpkgs";

    # Other tools
    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    ancs4linux.url = "./packages/ancs4linux";
    ancs4linux.inputs.nixpkgs.follows = "nixpkgs";
    claude-desktop.url = "github:aaddrick/claude-desktop-debian/89208a596a3e876a74f865fb5267996f666f4a09";
    winapps.url = "github:winapps-org/winapps";
    winapps.inputs.nixpkgs.follows = "nixpkgs";

    # Gaming
    nix-reshade.url = "github:LovingMelody/nix-reshade";
    nix-reshade.inputs.nixpkgs.follows = "nixpkgs";
    dbd-tools.url = "./packages/dbd-tools";
    dbd-tools.inputs.nixpkgs.follows = "nixpkgs";
    steam-launch-options.url = "./packages/steam-launch-options";
    steam-launch-options.inputs.nixpkgs.follows = "nixpkgs";
    osu-collect.url = "./packages/osu-collect";
    osu-collect.inputs.nixpkgs.follows = "nixpkgs";
    # Patches the Jackbox Megapicker for multi-directory game installs + ASAR integrity bypass.
    jackbox-megapicker-patcher.url = "github:Stefanuk12/jackbox_megapicker_patcher";
    jackbox-megapicker-patcher.inputs.nixpkgs.follows = "nixpkgs";
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
      # openldap 2.6.x syncrepl tests flake on timing; disable so both NixOS and home-manager configs build.
      homeOverlays = [
        hydenix.overlays.default
        # Exposes pkgs.helium for scripts that exec the browser directly
        inputs.helium.overlays.default
        (final: prev: {
          openldap = prev.openldap.overrideAttrs (_: { doCheck = false; });
        })
        # Bottles 63.2 needs `fvs2` but nixpkgs still ships old `fvs`; mirrors nixpkgs PR #511730, remove once merged.
        (final: prev: {
          fvs2 = final.callPackage ./packages/fvs2 { };
          bottles-unwrapped = prev.bottles-unwrapped.overrideAttrs (old: {
            propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ final.fvs2 ];
          });
        })
        # Spotify bumped ahead of nixpkgs to the latest stable snap (refresh via the snapcraft info API + nix store prefetch-file).
        (final: prev: {
          spotify = prev.spotify.overrideAttrs (_: rec {
            version = "1.2.92.147.g5b8f9367";
            rev = "97";
            src = final.fetchurl {
              name = "spotify-${version}-${rev}.snap";
              url = "https://api.snapcraft.io/api/v1/snaps/download/pOBIoZ2LrCB3rDohMxoYGnbN14EHOgD7_${rev}.snap";
              hash = "sha512-Gk0/WjfgJZIG+2w4teaznAk/7evOXUsuCikDvOhmhAQ5ksQV99VeiYnE+OJf7hHnrPaHoueERvIkk7Psed/kwA==";
            };
          });
        })
      ];
    in
    {
      nixosConfigurations = {
        home = lib.nixosSystem {
          system = "x86_64-linux";
          modules = [
            ./hosts/home/configuration.nix
            ./secrets
            {
              nixpkgs.pkgs = import nixpkgs {
                system = "x86_64-linux";
                config.allowUnfree = true;
                overlays = homeOverlays;
              };
            }
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
            overlays = [ claude-desktop.overlays.default ] ++ homeOverlays;
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
