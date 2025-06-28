{ config, ... }:

let
  userSettings = config.userSettings;
in {
  imports = [
    ../../../common/app/terminal
    ./cursor
    ./grimblast.nix
    ./hypridle.nix
    ./hyprlock.nix
    ./hyprpaper.nix
  ];

  wayland.windowManager.hyprland.enable = true;
  wayland.windowManager.hyprland.settings = {
    "$mod" = "SUPER";

    general = {
      no_border_on_floating = true;

      gaps_in = 4;
      gaps_out = 8;

      border_size = 0;
      resize_on_border = false;

      allow_tearing = false;
      layout = "dwindle";
    };

    decoration = {
      rounding = 15;
      rounding_power = 4;

      active_opacity = 0.93;
      inactive_opacity = 0.87;

      shadow = {
        enabled = false;
        range = 8;
        render_power = 4;
        color = "rgba(00000033)";
      };

      blur = {
        enabled = true;
        size = 8;
        passes = 2;
        new_optimizations = true;
        ignore_opacity = false;
        vibrancy = 0.25;
      };
    };

    bezier = [
      "myBezier, 0.05, 0.9, 0.1, 1.05"

      "overshot,0.05,0.9,0.1,1.1"
      "overshot,0.13,0.99,0.29,1.1"
    ];

    animation = [
      "windows, 1, 3, myBezier"
      "windowsOut, 1, 5, default, popin 80%"
      "border, 1, 10, default"
      "fade, 1, 5, default"
      "workspaces, 1, 7, default"

      "windowsMove, 1, 5, myBezier"
      "windowsOut, 1, 5, myBezier"
      "fade, 1, 5, default"
      "workspaces,1,4,overshot,slidevert"
    ];

    dwindle = {
      pseudotile = true;
      preserve_split = true;
    };

    input = {
      kb_layout = "iso_us";
      kb_variant = "intl";
      accel_profile = "flat";
    };

    monitor = [
      "HDMI-A-2, 1920x1080@75, 0x0, 1, vrr, 1"
      "DP-4, 1920x1080@165, 1920x0, 1, vrr, 1, bitdepth, 10,"
      ", preferred, auto, 1"
    ];

    bindm = [
      "SUPER, mouse:272, movewindow"
      "SUPER, mouse:273, resizewindow"
    ];
    layerrule = [
      "blur, waybar"
      "blurpopups, waybar"
      "ignorealpha 0.2, waybar"
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
