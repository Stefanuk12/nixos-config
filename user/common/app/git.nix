{ config, pkgs, username, ... }:
let
  userSettings = config.userSettings;
  systemSettings = config.systemSettings;
in {
  home.packages = with pkgs; [ git git-credential-manager ];
  programs.git.enable = true;
  programs.git.settings = {
    init.defaultBranch = "main";
    safe.directory = "/home/" + username + "/.dotfiles";
    user.name = userSettings.name;
    user.email = userSettings.email;
    credential = {
      helper = "manager";
      credentialStore = "cache";
    };
    credential."https://github.com" = {
      username = userSettings.ghUsername;
      identityFile = "/home/${username}/.ssh/id_ed25519";
    };
  };
}
