{
  description = "osu-collect - Download osu! beatmap collections from osu!collector (TUI)";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs =
    { self, nixpkgs }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      mkPackage =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        pkgs.rustPlatform.buildRustPackage rec {
          pname = "osu-collect";
          version = "0.2.2";

          src = pkgs.fetchFromGitHub {
            owner = "uwuclxdy";
            repo = "osu-collect";
            rev = "v${version}";
            hash = "sha256-n4qCuyoVV7jyZJaBcxfFbh5OKqfl/cHYPYV/Gba9Z3g=";
            fetchSubmodules = true;
          };

          cargoLock = {
            lockFile = ./Cargo.lock;
          };

          nativeBuildInputs = with pkgs; [
            cmake
            pkg-config
            perl
          ];

          buildInputs = with pkgs; [
            openssl
            zlib
          ];

          # 1. Force vendored realm-core to link system OpenSSL/Zlib instead of
          #    fetching prebuilt blobs (build sandbox has no network).
          # 2. Re-emit the realm archives after the bridge: cxx_build emits its
          #    link directive after build.rs's `-lrealm`, so ld needs a second
          #    pass to resolve the bridge's references to realm symbols.
          postPatch = ''
            substituteInPlace build.rs \
              --replace-fail '.define("REALM_BUILD_LIB_ONLY", "ON")' \
                '.define("REALM_BUILD_LIB_ONLY", "ON").define("REALM_USE_SYSTEM_OPENSSL", "ON")' \
              --replace-fail 'cxx_builder.compile("osu_realm_bridge");' \
                'cxx_builder.compile("osu_realm_bridge"); println!("cargo:rustc-link-lib=static=realm"); println!("cargo:rustc-link-lib=static=realm-parser");'
          '';

          # buildRustPackage's default configurePhase calls cmake on the workspace
          # root; realm-core is configured by the Rust build.rs via the cmake crate.
          dontUseCmakeConfigure = true;

          # No tests run during package build (the realm bridge needs a writable
          # filesystem layout that the sandbox doesn't expose the same way).
          doCheck = false;

          meta = {
            description = "Download osu! beatmap collections from osu!collector for free (TUI)";
            homepage = "https://github.com/uwuclxdy/osu-collect";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.linux;
            mainProgram = "osu-collect";
          };
        };
    in
    {
      packages = forAllSystems (system: rec {
        osu-collect = mkPackage system;
        default = osu-collect;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);
    };
}
