{ pkgs, ... }:
let
  edk2-patch_amd = pkgs.fetchpatch {
    url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/Hypervisor-Phantom/patches/EDK2/amd-edk2-stable202502.patch";
    hash = "sha256-3Fm0Fp5rWgD1hGxbJ2yYQJm1lJh+QrwH9NM7HMpiofo=";
    # Convert to DOS line endings
    # https://github.com/Scrut1ny/Hypervisor-Phantom/issues/43#top
    decode = "sed 's/$/\\r/'";
  };
  patched-edk2 = pkgs.edk2.overrideAttrs (finalAttrs: previousAttrs: {
    patches = [edk2-patch_amd];
  });
in {
  nixpkgs.overlays = [
    (final: prev: {
      OVMF = prev.OVMF.overrideAttrs (finalAttrs: previousAttrs: {
        patches = (previousAttrs.patches or []) ++ [edk2-patch_amd];
      });
    })
  ];
}
