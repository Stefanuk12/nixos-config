{ inputs, ... }:

{
  imports = [
    inputs.sops-nix.nixosModules.sops
  ];

  sops = {
    defaultSopsFile = ./.sops.yaml;
    defaultSopsFormat = "yaml";

    age.keyFile = "/home/user/.config/sops/age/keys.txt";
  };
}
