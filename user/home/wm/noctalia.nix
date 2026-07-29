{ inputs, ... }:

{
  imports = [ inputs.noctalia.homeModules.default ];

  programs.noctalia = {
    enable = true;
    # uwsm activates graphical-session.target, so the unit starts with the session.
    systemd.enable = true;

    settings = {
      shell = {
        font_family = "Arimo Nerd Font";
        polkit_agent = false; # polkit-gnome already runs as a system user service

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
        start = [ "launcher" "wallpaper" "workspaces" ];
        center = [ "clock" ];
        # cpu/ram are the two modules that used to be patched into HyDE's waybar layout 17.
        end = [
          "cpu"
          "ram"
          "media"
          "tray"
          "notifications"
          "clipboard"
          "network"
          "bluetooth"
          "volume"
          "control-center"
          "session"
        ];
      };

      system.monitor.enabled = true;

      notification.enable_daemon = true;

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
