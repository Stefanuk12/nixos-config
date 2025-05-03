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
    nerd-fonts.arimo
    nerd-fonts.jetbrains-mono
    # nerd-fonts.nerd-fonts-symbols-only
    noto-fonts-emoji
    sarasa-gothic
  ];
}
