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

        # Default is 100px reserved at each end. The full-date clock widened the centre section
        # enough to squeeze the end row, so give that 150px back rather than shorten the date.
        margin_ends = 24;

        # Pill per widget. capsule_radius is deliberately unset — that selects the automatic
        # full-pill radius rather than a fixed corner.
        capsule = true;

        # bar.cpp centres the centre section absolutely and caps each side slot at
        # (bar - centre)/2, clipping the overflow. workspaces is narrow, so unlike the full-date
        # clock it leaves both side slots roomy — which is what makes it safe to put there.
        start = [ "launcher" "clock" "media" ];
        center = [ "workspaces" ];
        end = [
          "group:resources" # how the box is doing
          "tray" # whatever apps put there
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
            id = "hardware";
            members = [ "network" "bluetooth" "volume" ];
          }
          {
            id = "shell";
            # notifications sits with the other shell surfaces rather than in a utilities pill:
            # its panel is the notification history, and clicking through to the control centre's
            # notification tab from right next door is the natural follow-on. No clipboard or
            # wallpaper button — SUPER+V and SUPER+SHIFT+W cover both.
            members = [ "notifications" "control-center" "session" ];
          }
        ];
      };

      # std::format chrono syntax, not bare strftime — the spec goes inside "{: }".
      widget.clock = {
        format = "{:%A %d %B %Y · %H:%M}";
        tooltip_format = "{:%H:%M:%S  ·  week %V}";
      };

      # title_scroll defaults to "none", which hard-clips a long title and squares off the
      # capsule's cap. "always" keeps the text moving inside a fixed-width pill, so it never
      # asks the bar for more room than it has — raising max_length instead makes it worse,
      # because the wider widget overflows the row and the leftmost item is what gets cut.
      # With the centre empty the end row is no longer budgeted against the clock, so this is a
      # readability choice rather than a fit constraint; longer titles still scroll.
      # show_label defaults to true, which prints the interface name ("eno1") next to the icon.
      # On a desktop with one wired link that never changes, the icon alone carries the state.
      widget.network.show_label = false;

      widget.media = {
        title_scroll = "always";
        max_length = 300;
        # Default false, which keeps an empty glyph and its padding in the bar whenever nothing
        # is playing. True drops the widget entirely instead.
        hide_when_no_media = true;
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
