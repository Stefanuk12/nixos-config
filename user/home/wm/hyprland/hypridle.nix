{ pkgs, lib, inputs, ... }:

let
  suspendScript = pkgs.writeShellScript "suspend-script" ''
    ${pkgs.pipewire}/bin/pw-cli i all | ${pkgs.ripgrep}/bin/rg running
    # only suspend if audio isn't running
    if [ $? == 1 ]; then
      ${pkgs.systemd}/bin/systemctl suspend
    fi
  '';
in {
  imports = [
    inputs.hypridle.homeManagerModules.default
  ];

  services.hypridle = {
    enable = true;
    
    lockCmd = lib.getExe pkgs.hyprlock;
    beforeSleepCmd = "${pkgs.systemd}/bin/loginctl lock-session";
    afterSleepCmd = "notify-send 'Zzz'";
    ignoreDbusInhibit = true;

    listeners = [{
      timeout = 500;
      onTimeout = suspendScript.outPath;
      onResume = "notify-send 'Welcome back!'";
    }];
  };
}
