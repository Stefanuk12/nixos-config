{ config, pkgs, username, ... }:
let
  userSettings = config.userSettings;
  systemSettings = config.systemSettings;
in {
  home.packages = with pkgs; [ git git-credential-manager ];
  programs.git = {
    enable = true;
    userName = userSettings.name;
    userEmail = userSettings.email;
    extraConfig = {
      credential = {
        helper = "manager";
        credentialStore = "cache";
      };
      init.defaultBranch = "main";
      safe.directory = "/home/" + username + "/.dotfiles";
    };
    extraConfig.credential."https://github.com".username = userSettings.ghUsername;
  };
}
