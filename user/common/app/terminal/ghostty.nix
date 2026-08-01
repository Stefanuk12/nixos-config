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
      # Ghostty's default pairs ctrl+insert (clipboard) with shift+insert (PRIMARY selection), so
      # the two don't round-trip; point the paste at the clipboard the copy actually wrote to.
      keybind = [ "shift+insert=paste_from_clipboard" ];
    };
  };
}
