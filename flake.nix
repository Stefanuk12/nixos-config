{
  description = "yo mother";

  inputs = {
    # nixpkgs is deliberately left undeclared; it resolves through the flake registry.
    nixos-hardware.url = "github:nixos/nixos-hardware/master";

    # Desktop shell: bar, launcher, notifications, OSD, lock screen, wallpaper.
    noctalia.url = "github:noctalia-dev/noctalia";
    noctalia.inputs.nixpkgs.follows = "nixpkgs";
    noctalia-greeter.url = "github:noctalia-dev/noctalia-greeter";
    noctalia-greeter.inputs.nixpkgs.follows = "nixpkgs";

    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";

    sops-nix.url = "github:Mic92/sops-nix";
    sops-nix.inputs.nixpkgs.follows = "nixpkgs";

    Neve.url = "github:redyf/Neve";

    nix-colors.url = "github:misterio77/nix-colors";

    nixos-facter-modules.url = "github:numtide/nixos-facter-modules";
    # Local working tree for testing (was github:Stefanuk12/BarelyMetal/update)
    barely-metal.url = "path:/home/stefan/Documents/Backup/GitHub/BarelyMetal";
    barely-metal.inputs.nixpkgs.follows = "nixpkgs";
    nixvirt.url = "github:Stefanuk12/NixVirt/patch-pulseaudio";
    nixvirt.inputs.nixpkgs.follows = "nixpkgs";
    osx-kvm.url = "./packages/osx-kvm";
    osx-kvm.inputs.nixpkgs.follows = "nixpkgs";

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

    # Not in nixpkgs yet (PR pending); packaged from the upstream .deb.
    helium.url = "github:oxcl/nix-flake-helium-browser";
    helium.inputs.nixpkgs.follows = "nixpkgs";

    # Fork that serves Proton's CAPTCHA on a local page so a flagged login can be finished in a
    # browser (stock hydroxide just errors out on 9001). Built by the overlay below.
    hydroxide-jahroots = {
      url = "github:Jahroots/hydroxide/60a7c7e846afcf49743ae28afd6692d82a3db8fc";
      flake = false;
    };

    # Builds a Comfy-themed Spotify; spicetify itself can't patch a read-only store path.
    spicetify-nix.url = "github:Gerg-L/spicetify-nix";
    spicetify-nix.inputs.nixpkgs.follows = "nixpkgs";

    nix-flatpak.url = "github:gmodena/nix-flatpak/?ref=latest";
    ancs4linux.url = "./packages/ancs4linux";
    ancs4linux.inputs.nixpkgs.follows = "nixpkgs";
    claude-desktop.url = "github:aaddrick/claude-desktop-debian/89208a596a3e876a74f865fb5267996f666f4a09";
    winapps.url = "github:winapps-org/winapps";
    winapps.inputs.nixpkgs.follows = "nixpkgs";

    nix-reshade.url = "github:LovingMelody/nix-reshade";
    nix-reshade.inputs.nixpkgs.follows = "nixpkgs";
    dbd-tools.url = "./packages/dbd-tools";
    dbd-tools.inputs.nixpkgs.follows = "nixpkgs";
    steam-launch-options.url = "./packages/steam-launch-options";
    steam-launch-options.inputs.nixpkgs.follows = "nixpkgs";
    osu-collect.url = "./packages/osu-collect";
    osu-collect.inputs.nixpkgs.follows = "nixpkgs";
    # PSVR2 on SteamVR: Ignition hosts the Windows driver in Proton, PSVR2Toolkit wraps it, plus
    # the SteamVRLinuxFixes layer, play-area app, firmware updater and xr-hardware udev rules.
    psvr2-toolkit.url = "./packages/psvr2-toolkit";
    psvr2-toolkit.inputs.nixpkgs.follows = "nixpkgs";
    # steamclient.so hook: family-share lock bypass, DLC unlocking, etc. Not in nixpkgs.
    sls-steam.url = "github:AceSLS/SLSsteam";
    sls-steam.inputs.nixpkgs.follows = "nixpkgs";
    # Patches the Jackbox Megapicker for multi-directory game installs + ASAR integrity bypass.
    jackbox-megapicker-patcher.url = "github:Stefanuk12/jackbox_megapicker_patcher";
    jackbox-megapicker-patcher.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
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
      homeOverlays = [
        inputs.noctalia.overlays.default
        inputs.helium.overlays.default
        # Ungoogled strips Chrome's page translation, and helium's native translate (0.13.4.1) is
        # macOS-only, so load an extension instead. Baked into the package rather than set only via
        # programs.helium.flags, because that override would fork the store path away from the one
        # the hyprland exec-once launcher and the .desktop entry resolve. The module re-overrides
        # `flags`, so the same list is repeated in user/home/app/browser/helium.nix; both must match.
        # --load-extension was only removed from Chrome-branded builds (137+), not unbranded
        # chromium; check that first if the extension ever stops appearing.
        (final: prev: {
          helium-autotranslate = final.callPackage ./packages/helium-autotranslate { };
          helium = prev.helium.override {
            flags = [ "--load-extension=${final.helium-autotranslate}" ];
          };
        })
        # rbw with WebAuthn 2FA (aokellermann/rbw PR #334); drop once merged into nixpkgs.
        (final: prev: {
          rbw = final.callPackage ./packages/rbw-webauthn { };
        })
        (final: _prev: {
          thunderbird-simplelogin = final.callPackage ./packages/thunderbird-simplelogin { };
        })
        (final: _prev: {
          nuvio = final.callPackage ./packages/nuvio { };
        })
        # nixpkgs monado (25.1.0) has no psvr2 driver at all; drop once one lands there with
        # working Sense controllers.
        (final: _prev: {
          monado-psvr2 = final.callPackage ./packages/monado-psvr2 { };
        })
        # 14.0.0 registers an Android device with a double-length serial, which Audible began
        # refusing with "License Denied" in Sept 2026 (Libation #2021). Mirrors nixpkgs PR #560766;
        # drop once the nixpkgs input carries libation >= 14.2.0.
        (final: prev: {
          libation = final.callPackage ./packages/libation { };
        })
        # Bottles 63.2 needs `fvs2`, nixpkgs still ships `fvs`; mirrors nixpkgs PR #511730.
        (final: prev: {
          fvs2 = final.callPackage ./packages/fvs2 { };
          bottles-unwrapped = prev.bottles-unwrapped.overrideAttrs (old: {
            propagatedBuildInputs = (old.propagatedBuildInputs or [ ]) ++ [ final.fvs2 ];
          });
        })
        # 2.44.0's css-map lacks the Spotify 1.2.92+ playback-progressbar-container hash, which
        # hides Comfy's progress bar; drop once nixpkgs' spicetify-cli is >= 2.45.0.
        (final: prev: {
          spicetify-cli = prev.spicetify-cli.overrideAttrs (_: {
            version = "2.45.1";
            src = final.fetchFromGitHub {
              owner = "spicetify";
              repo = "cli";
              tag = "v2.45.1";
              hash = "sha256-Mu97p0HlvmEMkPV/VvHztJ1VqocxXoAXRtDKLGYd9mk=";
            };
            vendorHash = "sha256-nrUaocs+so35MDxC6TkRSakYKWmhoysrvhE6fXRvYco=";
          });
        })
        # Ahead of nixpkgs; refresh via the snapcraft info API + `nix store prefetch-file`.
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
        # xdph never closes the linux-dmabuf format-table fd, so screen sharing dies with EMFILE
        # after about a day of uptime. Drop once the fix lands upstream; nixpkgs is on 1.4.0.
        (final: prev: {
          xdg-desktop-portal-hyprland = prev.xdg-desktop-portal-hyprland.overrideAttrs (old: {
            patches = (old.patches or [ ]) ++ [ ./packages/xdph-format-table-fd.patch ];
          });
        })
        # FL Studio 26.1.4+ signs its binaries with non-DER-ordered authenticated attributes;
        # crypt32 re-sorted them before hashing, so the self-check failed with
        # TRUST_E_CERT_SIGNATURE. Wine MR !11824 (bug 60273); drop once it ships in nixpkgs' wine.
        (final: prev: {
          wineWow64Packages = prev.wineWow64Packages // {
            staging = prev.wineWow64Packages.staging.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./packages/wine-crypt32-signed-attr-order.patch ];
            });
          };
        })
        # qtmultimedia reads pa_context_get_state() off a null context once PulseAudio drops the
        # connection, so libpulse's assert aborts the host app (Dolphin's media preview). Drop once
        # the null guard lands upstream; nixpkgs is on 6.11.2.
        # Not pkgs.qt6: overrideScope drops the `override` that python-packages calls on it.
        (final: prev: {
          qt6Packages = prev.qt6Packages.overrideScope (_: qprev: {
            qtmultimedia = qprev.qtmultimedia.overrideAttrs (old: {
              patches = (old.patches or [ ]) ++ [ ./packages/qtmultimedia-pulse-null-context.patch ];
            });
          });
        })
        # AutoVirt's AMD-v11.0.0.patch is cut against QEMU 11.0.0, and its hw/nvme/ctrl.c hunk fails
        # on 11.1.0, which gained a native `model` device param that makes the hunk redundant. Hold
        # QEMU here until BarelyMetal moves the nvme spoof onto `model=`; the tasn1 patch is
        # 11.1-only and does not apply to this tree.
        (final: prev: {
          qemu = prev.qemu.overrideAttrs (old: rec {
            version = "11.0.2";
            src = final.fetchurl {
              url = "https://download.qemu.org/qemu-${version}.tar.xz";
              hash = "sha256-N0X26oji6H/g3IOLKx1OCncL9I4BodWhhoQqH/92zPU=";
            };
            patches = builtins.filter (
              p: !(final.lib.hasSuffix "fix-tls-tests-without-tasn1.patch" (toString p))
            ) (old.patches or [ ]);
          });
        })
        # Rebuilds pkgs.hydroxide from the pinned input above so aerc.nix's service picks it up.
        # Recompute vendorHash on bump.
        (final: prev: {
          hydroxide = prev.buildGoModule {
            pname = "hydroxide";
            version = "0-unstable-jahroots";
            src = inputs.hydroxide-jahroots;
            vendorHash = "sha256-BIHvURCgqEzhl4NsVB7vBwLqMPxkM3CQgHmIcSTdOE4=";
            subPackages = [ "cmd/hydroxide" ];
            meta = prev.hydroxide.meta;
          };
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
