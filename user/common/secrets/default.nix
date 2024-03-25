{ pkgs, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  sops = {  
    defaultSopsFile = ./.sops.yaml;
    defaultSopsFormat = "yaml";

    age.keyFile = "/home/stefan/.config/sops/age/keys.txt";
  };
}
