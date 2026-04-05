{ pkgs, inputs, ... }:

{
  imports = [ inputs.ancs4linux.nixosModules.default ];

  services.usbmuxd.enable = true;

  environment.systemPackages = with pkgs; [
    libimobiledevice
    ifuse
  ];

  services.ancs4linux = {
    enable = true;
    advertisingName = "stefan_pc";
    user = "stefan";
  };
}
