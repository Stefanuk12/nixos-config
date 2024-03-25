{ pkgs, inputs, ... }:

{
  imports = [
    inputs.sops-nix.homeManagerModules.sops
  ];

  home.file.".config/sops/age/public.txt".text = "age1h08pk2dk8x6rvrdqyke85tcfy6s5n0vxpjausn6a968tsa2xae5shc5qec";

  sops = {  
    defaultSopsFile = ./secrets.yaml;
    defaultSopsFormat = "yaml";

    age.keyFile = "/home/user/.config/sops/age/keys.txt";    
    secrets = {
      test.path = "%r/test.txt";
    };
  };
}
