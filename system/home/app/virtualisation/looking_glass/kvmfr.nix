{ ... }:

{
  services.udev.extraRules = ''
    SUBSYSTEM=="kvmfr", OWNER="stefan", GROUP="kvm", MODE="0660"
  '';
}