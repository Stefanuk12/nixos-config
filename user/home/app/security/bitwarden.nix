{
  config,
  pkgs,
  ...
}: {
  home.packages = with pkgs; [
    bitwarden-cli
    bitwarden-menu
  ];

  #sops.secrets.bitwarden-master = {
  #  sopsFile = ../../secrets/user/bitwarden.yaml;
  #  owner = config.users.users.stefan.name;
  #  key = "petrovic.foo/key";
  #};
}
