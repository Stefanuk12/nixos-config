{ pkgs, lib, ... }:

{
  imports = [
    ./wayland.nix
  ];

  services.udev.packages = lib.singleton (
    pkgs.writeTextFile {
      name = "gpu-symlinks";
      text = ''
        KERNEL=="card*", KERNELS=="0000:03:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/rx6950xt"
        KERNEL=="card*", KERNELS=="0000:0e:00.0", SUBSYSTEM=="drm", SUBSYSTEMS=="pci", SYMLINK+="dri/amd-igpu"
      '';
      destination = "/etc/udev/rules.d/70-gpu-symlinks.rules";
    }
  ); 
  
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
    portalPackage = pkgs.xdg-desktop-portal-hyprland;
  };
}
