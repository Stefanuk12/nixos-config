{ config, pkgs, ... }:
let
  userSettings = config.userSettings;
  systemSettings = config.systemSettings;
in {
  home.packages = with pkgs; [ git ];
  programs.git = {
    enable = true;
    userName = userSettings.name;
    userEmail = userSettings.email;
    extraConfig = {
      init.defaultBranch = "main";
      safe.directory = "/home/" + systemSettings.username + "/.dotfiles";
    };
  };
}
