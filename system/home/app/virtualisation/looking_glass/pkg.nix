{ pkgs, ... }:

{
  hardware.opengl.enable = true;
  virtualisation.spiceUSBRedirection.enable = true;

  systemd.tmpfiles.rules = [
    "f /dev/shm/looking-glass 0660 stefan qemu-libvirtd -"
  ];
  environment.systemPackages = with pkgs; [
    looking-glass-client
    ddcutil
  ];
}
