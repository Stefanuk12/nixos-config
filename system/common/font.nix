{ pkgs, ... }:

{
  fonts.fontconfig = {
    defaultFonts = {
      emoji = [ "Noto Color Emoji" ];
      monospace = [ "JetBrainsMono Nerd Font" "Cascadia Code" "Sarasa Mono SC" ];
      sansSerif = [ "Arimo Nerd Font" "Sarasa Gothic SC" ];
      serif = [ "Arimo Nerd Font" "Sarasa Gothic SC" ];
    };
    includeUserConf = false;
  };
  fonts.packages = with pkgs; [
    cascadia-code
    (nerdfonts.override { fonts = [ "Arimo" "JetBrainsMono" "NerdFontsSymbolsOnly" ]; })
    noto-fonts-emoji
    sarasa-gothic
  ];
}
