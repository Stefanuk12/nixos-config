{ inputs, config, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];
  # This runs at login, before any graphical pinentry can service the GPG key's passphrase, so
  # gpg-agent fails with "Inappropriate ioctl for device". The age key needs no passphrase and
  # already decrypts these files; it is the same one the system sops uses.
  sops.age.keyFile = "${config.home.homeDirectory}/.config/sops/age/keys.txt";
}
