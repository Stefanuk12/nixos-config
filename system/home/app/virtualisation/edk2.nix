{ pkgs, ... }:
let
  edk2-patch_amd = pkgs.fetchpatch {
    url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/patches/EDK2/amd-edk2-stable202511.patch";
    hash = "sha256-yvu1Elbn1a8WHIu11sH3F8C/eFAM+WoQ2/cCJk1lFfc=";
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
