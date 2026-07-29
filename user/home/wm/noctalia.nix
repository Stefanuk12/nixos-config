{ inputs, ... }:

let
  # The G24F. noctalia matches on connector names, not Hyprland monitor IDs, and left empty it
  # falls back to whichever output enumerates first — HDMI-A-1, the Acer.
  mainMonitor = "DP-1";
in
{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    # uwsm activates graphical-session.target, so the unit starts with the session.
    systemd.enable = true;

    settings = {
      shell = {
        font_family = "Arimo Nerd Font";
        polkit_agent = true;

        # noctalia.service restarts on every config change (the module sets X-Restart-Triggers),
        # which takes its launched children down with it. Detaching them into their own transient
        # units is upstream's recommendation whenever systemd.enable is on.
        launch_apps_as_systemd_services = true;

        # Pushes the live palette/wallpaper to the greeter's sync.toml. Needs pkexec at runtime,
        # so the first sync after login prompts for a password.
        greeter_sync.auto_sync = true;
        clipboard_enabled = true;
      };

      theme = {
        mode = "dark";
        source = "builtin";
        builtin = "Catppuccin";
      };

      bar.main = {
        position = "top";

        # Pill per widget. capsule_radius is deliberately unset — that selects the automatic
        # full-pill radius rather than a fixed corner.
        capsule = true;

        # Left is where you act, centre is the glance, right reads outward from "what this
        # machine is doing" to "things I click to change it".
        start = [ "launcher" "workspaces" ];
        center = [ "clock" ];
        end = [
          "media" # what is playing
          "group:resources" # how the box is doing
          "tray" # whatever apps put there
          "group:utilities"
          "group:hardware"
          "group:shell" # panels, so the far corner stays the session button
        ];

        # A group renders as one pill; loose widgets keep their own. Related things therefore
        # read as a unit instead of a row of identical islands.
        capsule_group = [
          {
            id = "resources";
            # The two modules that used to be patched into HyDE's waybar layout 17.
            members = [ "cpu" "ram" ];
          }
          {
            id = "utilities";
            members = [ "clipboard" "notifications" ];
          }
          {
            id = "hardware";
            members = [ "network" "bluetooth" "volume" ];
          }
          {
            id = "shell";
            members = [ "wallpaper" "control-center" "session" ];
          }
        ];
      };

      # std::format chrono syntax, not bare strftime — the spec goes inside "{: }".
      widget.clock = {
        format = "{:%A %d %B %Y · %H:%M}";
        tooltip_format = "{:%H:%M:%S  ·  week %V}";
      };

      system.monitor.enabled = true;

      # The account is declared here so it keeps a stable id; the OAuth refresh token itself
      # lives in the Secret Service and is obtained by signing in via Settings -> Calendar.
      calendar = {
        enabled = true;
        refresh_minutes = 15;
        account.google = {
          type = "google";
          name = "Google";
        };
      };

      osd = {
        monitors = [ mainMonitor ];
        # The bare media keys already draw their own popup via spotify-osd.
        kinds.media = false;
      };

      dock.monitors = [ mainMonitor ];

      notification = {
        enable_daemon = true;
        monitors = [ mainMonitor ];
      };

      # monitors deliberately left unset here: an explicit list blanks every other output, and a
      # lock screen should cover the Acer too.
      lockscreen.enabled = true;

      idle.behavior = {
        lock = {
          timeout = 900;
          action = "lock";
          enabled = true;
        };
        screen-off = {
          timeout = 1200;
          action = "screen_off";
          enabled = true;
        };
      };
    };
  };
}
