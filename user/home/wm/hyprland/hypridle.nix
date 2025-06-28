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
  services.hypridle.enable = true;

  # https://wiki.hyprland.org/Hypr-Ecosystem/hypridle/
  services.hypridle.settings = {
    general = {
      lock_cmd = lib.getExe pkgs.hyprlock;
      before_sleep_cmd = "${pkgs.system}/bin/loginctl lock-session";
      after_sleep_cmd = "notify-send 'Zzz'";
      ignoreDbusInhibit = false;
    };

    listener = [
      {
        timeout = 500;
        on-timeout = suspendScript.outPath;
        on-resume = "notify-send 'Welcome back!'";
      }
    ];
  };
}
