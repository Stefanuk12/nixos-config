{ pkgs, ... }:
let
  edk2-patch_amd = pkgs.fetchpatch {
    url = "https://raw.githubusercontent.com/Scrut1ny/AutoVirt/refs/heads/main/patches/EDK2/Archive/AMD-edk2-stable202511.patch";
    hash = "sha256-p0O0FrHAcnY+8safwXg4uba/vXvKoxm80pLJW4n46Cs=";
    decode = "sed 's/$/\\r/'";
  };
in
{
  nixpkgs.overlays = [
    (final: prev: {
      edk2 = prev.edk2.overrideAttrs (oldAttrs: {
        version = "202511";
        src = prev.fetchFromGitHub {
          owner = "tianocore";
          repo = "edk2";
          rev = "edk2-stable202511";
          fetchSubmodules = true;
          hash = "sha256-R/rgz8dWcDYVoiM67K2UGuq0xXbjjJYBPtJ1FmfGIaU=";
        };
        patches = (oldAttrs.patches or [ ]) ++ [ edk2-patch_amd ];
      });
      OVMF = prev.OVMF.override { edk2 = final.edk2; };
    })
  ];
}
