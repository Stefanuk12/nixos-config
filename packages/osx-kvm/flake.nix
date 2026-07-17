{
  description = "macOS-guest image stack: OVMF, OpenCore EFI, kexts, config.plist generator";

  inputs.nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs }:
    let
      inherit (nixpkgs) lib;
      systems = [ "x86_64-linux" "aarch64-linux" ];
      eachSystem = lib.genAttrs systems;
      mkOsxKvm = { pkgs, lib ? pkgs.lib }: import ./. { inherit pkgs lib; };

      perSystem = system:
        let
          osxKvm   = mkOsxKvm { pkgs = nixpkgs.legacyPackages.${system}; };
          fetchers = lib.filterAttrs (_: lib.isDerivation) osxKvm.fetchBaseSystem;
          versions = lib.removeAttrs fetchers [ "default" ];
        in { inherit osxKvm fetchers versions; };
    in
    {
      lib.mkOsxKvm = mkOsxKvm;

      packages = eachSystem (system:
        let s = perSystem system;
            mkPkg = n: v: lib.nameValuePair "fetch-basesystem-${n}" v;
        in {
          default          = s.fetchers.default;
          fetch-basesystem = s.fetchers.default;
          ovmf-code        = s.osxKvm.ovmf.code;
          opencore-efi     = s.osxKvm.opencore.efi;
          ocvalidate       = s.osxKvm.opencore.ocvalidate;
          oc-snapshot      = s.osxKvm.ocSnapshot;
        } // lib.filterAttrs (_: lib.isDerivation) s.osxKvm.kexts
          // lib.mapAttrs' mkPkg s.versions);

      apps = eachSystem (system:
        let s = perSystem system;
            mkApp = drv: { type = "app"; program = lib.getExe drv; };
            mkA   = n: v: lib.nameValuePair "fetch-basesystem-${n}" (mkApp v);
        in {
          default          = mkApp s.fetchers.default;
          fetch-basesystem = mkApp s.fetchers.default;
        } // lib.mapAttrs' mkA s.versions);

      # End-to-end image build per bundled profile — exercises mkEfi, config-plist render, OCSnapshot, ocvalidate and the FAT/GPT path.
      checks.x86_64-linux =
        let osxKvm = mkOsxKvm { pkgs = nixpkgs.legacyPackages.x86_64-linux; };
        in lib.mapAttrs'
          (n: p: lib.nameValuePair "image-${n}" (osxKvm.mkImage { profile = p; }))
          osxKvm.profiles;
    };
}
