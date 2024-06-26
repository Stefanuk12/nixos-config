{ config, ... }:

let
  userSettings = config.userSettings;
in {
  imports = [
    ../../../common/app/terminal
    ./cursor
    ./hypridle.nix
    ./hyprlock.nix
    ./grimblast.nix
  ];

  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    monitor = [
      "HDMI-A-2, 1920x1080@75, 0x0, 1, vrr, 1"
      "DP-4, 1920x1080@165, 1920x0, 1, vrr, 1, bitdepth, 10,"
      ", preferred, auto, 1"
    ];
    input = {
      "force_no_accel" = true;
      "kb_layout" = "us";
    };
    bindm = [
      "SUPER, mouse:272, movewindow"
      "SUPER, mouse:273, resizewindow"
    ];
    bind =
      [
        "$mod, F, exec, firefox"

        "SUPER, RETURN, exec, ${userSettings.terminal}"
        "SUPER, code:47, exec, fuzzel"
        "SUPER, Q, killactive"
        "SUPERSHIFT, Q, exit"

        "CONTROLALT, Delete, exec, hyprctl dispatch exit"

        "CONTROLALT, Left, exec, sudo ddcutil -d 2 setvcp 60 0x0f"
        "CONTROLALT, Right, exec, sudo ddcutil -d 2 setvcp 60 0x11"
      ]
      ++ (
        builtins.concatLists (builtins.genList (
            x: let
              ws = let
                c = (x + 1) / 10;
              in
                builtins.toString (x + 1 - (c * 10));
            in [
              "$mod, ${ws}, workspace, ${toString (x + 1)}"
              "$mod SHIFT, ${ws}, movetoworkspace, ${toString (x + 1)}"
            ]
          )
          10)
      );
  };
}
