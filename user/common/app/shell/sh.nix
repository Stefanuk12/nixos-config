{ pkgs, ... }:
let
  shellAliases = {
    ls = "eza --icons -l -T -L=1";
  };
in {
  programs.zsh = {
    inherit shellAliases;

    enable = true;
    autosuggestion.enable = true;
    syntaxHighlighting.enable = true;
    initExtra = ''

    '';
  };

  programs.bash = {
    inherit shellAliases;

    enable = true;
    enableCompletion = true;
  };

  home.packages = with pkgs; [
    eza
  ];
}
