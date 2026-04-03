{
  config,
  pkgs,
  lib,
  ...
}:

{
  boot.kernelParams = [ "kvmfr.static_size_mb=32" ];
  boot.initrd.kernelModules = [ "kvmfr" ];
  boot.extraModulePackages = [ pkgs.linuxKernel.packages.linux_6_18.kvmfr ];
  services.udev.packages = lib.singleton (
    pkgs.writeTextFile {
      name = "kvmfr";
      text = ''
        SUBSYSTEM=="kvmfr", GROUP="kvm", MODE="0660", TAG+="uaccess"
      '';
      destination = "/etc/udev/rules.d/70-kvmfr.rules";
    }
  );
}
