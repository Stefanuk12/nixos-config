{ inputs, config, ... }:

{
  imports = [
    inputs.rbw-fetch.nixosModules.default
  ];

  sops.secrets."bw/master_password" = {
    sopsFile = ../../../../secrets/home/bitwarden.yaml;
    key = "master_password";
    # Readable by stefan so the user-side pinentry-smart in bitwarden.nix can
    # serve it for `rbw unlock` non-interactively. The rbw-fetch system service
    # uses LoadCredential which reads as root, so this is invisible to it.
    owner = "stefan";
    mode = "0400";
  };
  sops.secrets."bw/email" = {
    sopsFile = ../../../../secrets/home/bitwarden.yaml;
    key = "email";
    # Readable by stefan so user-side home-manager activations can read it
    # (e.g. the rbw-config activation in user/home/app/security/bitwarden.nix).
    # The rbw-fetch system service uses LoadCredential which reads as root, so
    # this change is invisible to it.
    owner = "stefan";
    mode = "0400";
  };
  sops.secrets."bw/api_client_id" = {
    sopsFile = ../../../../secrets/home/bitwarden.yaml;
    key = "api_client_id";
    mode = "0400";
  };
  sops.secrets."bw/api_client_secret" = {
    sopsFile = ../../../../secrets/home/bitwarden.yaml;
    key = "api_client_secret";
    mode = "0400";
  };

  rbw-fetch = {
    emailFile = config.sops.secrets."bw/email".path;
    masterPasswordFile = config.sops.secrets."bw/master_password".path;
    apiClientIdFile = config.sops.secrets."bw/api_client_id".path;
    apiClientSecretFile = config.sops.secrets."bw/api_client_secret".path;
  };
}