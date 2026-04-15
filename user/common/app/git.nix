{
  lib,
  config,
  pkgs,
  username,
  ...
}:
let
  userSettings = config.userSettings;
  systemSettings = config.systemSettings;
in
{
  home.packages = with pkgs; [
    git
    git-credential-manager
    pass
    pass-git-helper
  ];

  sops.secrets."gh_pub_read_pat" = {
    key = "token";
    sopsFile = ../../../secrets/common/gh_pub_read_pat.yaml;
  };

  home.activation.nix-github-token = lib.hm.dag.entryAfter [ "sopsNix" ] ''
    token=$(cat ${config.sops.secrets.gh_pub_read_pat.path})
    echo "access-tokens = github.com=$token" > "$HOME/.config/nix/access-tokens"
    chmod 600 "$HOME/.config/nix/access-tokens"
  '';

  nix.package = pkgs.nix;
  nix.extraOptions = ''
    !include /home/stefan/.config/nix/access-tokens
  '';

  programs.password-store = {
    enable = true;
    package = pkgs.pass;
    settings = {
      PASSWORD_STORE_DIR = "$XDG_DATA_HOME/password-store";
    };
  };
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
