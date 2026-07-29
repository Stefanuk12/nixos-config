{ inputs, pkgs, ... }:

{
  imports = [ inputs.noctalia-greeter.nixosModules.default ];

  programs.noctalia-greeter = {
    enable = true;
    package = inputs.noctalia-greeter.packages.${pkgs.stdenv.hostPlatform.system}.default;
    settings = {
      # Picker label, not the .desktop id; uwsm is what gets graphical-session.target activated.
      session.default = "Hyprland (uwsm-managed)";
      user.default = "stefan";

      appearance = {
        # "Synced", not "Catppuccin": a named builtin here overrides whatever greeter_sync
        # writes to sync.toml, which would defeat auto_sync. No [appearance.palette] block
        # either, since a complete one also wins over the synced values.
        scheme = "Synced";
        theme_mode = "dark";
      };

      # Stock "us", not the iso_us layout: greetd has no XKB_CONFIG_ROOT for the extraLayouts
      # tree, and a layout that fails to load here means no way to type a password.
      keyboard.layout = "us";

      cursor = {
        theme = "Bibata-Modern-Ice";
        size = 24;
      };
    };
  };

  # noctalia keeps the Google Calendar OAuth refresh token in the Secret Service, and nothing
  # else on this host provides one. Hooking it into greetd's PAM stack unlocks it at login so
  # the token survives without a second prompt.
  services.gnome.gnome-keyring.enable = true;
  security.pam.services.greetd.enableGnomeKeyring = true;

  environment.systemPackages = [ pkgs.bibata-cursors ];
}
