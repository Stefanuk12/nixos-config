{ config, ... }:

{
  # noctalia honours $TERMINAL before falling back to scanning a candidate list, so this pins
  # the choice instead of leaving it to whatever happens to be on PATH.
  home.sessionVariables.TERMINAL = config.userSettings.terminal;

  programs.ghostty = {
    enable = true;
    settings = {
      # Ghostty's bundled theme names are capitalised and spaced; the slug form silently fails.
      theme = "Catppuccin Mocha";
      background-opacity = 0.75;
      font-family = "JetBrainsMono Nerd Font";
      confirm-close-surface = false;
    };
  };
}
