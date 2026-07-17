# Patched OVMF for macOS guests: CODE from the kholia/OSX-KVM fork with macOS-specific edk2 patches, VARS the stock 4M empty-NVRAM template from nixpkgs.

{ fetchurl, OVMF }:

let
  rev = "4c378a4b5e0b219783683012bec680325eb40719";
in
{
  code = fetchurl {
    url = "https://github.com/kholia/OSX-KVM/raw/${rev}/OVMF_CODE_4M.fd";
    sha256 = "0xs53dr8jzx586b2mk15sr01b23drq2iv7gpl51zkrv5k7xdgv3x";
  };
  varsTemplate = "${OVMF.fd}/FV/OVMF_VARS.fd";
}
