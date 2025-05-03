{pkgs, ...}: let
  ekd2-patch_amd = pkgs.fetchpatch {
    url = "https://raw.githubusercontent.com/Scrut1ny/Hypervisor-Phantom/refs/heads/main/Hypervisor-Phantom/patches/EDK2/amd-edk2-stable202502.patch";
    hash = "sha256-z9eP9wtMcno9dAH9UyhK0z7TE40IuriAMna2gaS/0sk=";
    # Convert to DOS line endings
    # https://github.com/Scrut1ny/Hypervisor-Phantom/issues/43#top
    decode = "sed 's/$/\\r/'";
    # stable = ./amd-edk2-stable202411.patch;
  };
  patched-edk2 = pkgs.edk2.overrideAttrs (finalAttrs: previousAttrs: {
    patches = [edk2-patch_amd];
  })
in {
  nixpkgs.overlays = [
    (final: prev: {
      edk2 = patched-edk2;
    })
  ];
}
