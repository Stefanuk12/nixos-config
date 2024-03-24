{ config, ... }:

let
  userSettings = config.userSettings;
in {
  imports = [
    ../../../common/app/terminal
  ];

  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";
    bind =
      [
        "$mod, F, exec, firefox"
        ", Print, exec, grimblast copy area"

        "SUPER, RETURN, exec, ${userSettings.terminal}"
        "SUPER, code:47, exec, fuzzel"
        "SUPER, Q, killactive"
        "SUPERSHIFT, Q,exit"

        "CONTROLALT, Delete, exec, hyprctl dispatch exit"
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
