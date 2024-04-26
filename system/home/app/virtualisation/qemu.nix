{pkgs, ...}: let
  # special anti-detection emulator
  qemu-anti-detection =
    pkgs.qemu_kvm.overrideAttrs (finalAttrs: previousAttrs: {
      # ref: https://github.com/zhaodice/qemu-anti-detection
      patches =
        (previousAttrs.patches or [])
        ++ [
          (pkgs.fetchpatch {
            url = "https://raw.githubusercontent.com/zhaodice/qemu-anti-detection/main/qemu-8.2.0.patch";
            sha256 = "sha256-RG4lkSWDVbaUb8lXm1ayxvG3yc1cFdMDP1V00DA1YQE=";
          })
        ];
    });
in {
  # ref: https://github.com/NixOS/nixpkgs/issues/115996
  virtualisation.libvirtd = {
    allowedBridges = ["nm-bridge" "virbr0"];
    qemu = {
      package = qemu-anti-detection;
    };
  };

  environment.systemPackages = [qemu-anti-detection];
}
