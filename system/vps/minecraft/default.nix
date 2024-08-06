{ inputs, config, lib, ... }:

{
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./servers/survival
  ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  sops.secrets.minecraft = {
    owner = "minecraft";
    group = "minecraft";
    mode = "0400";
    sopsFile = ../../../secrets/vps/minecraft.yaml;
  };

  services.minecraft-servers = {
    enable = true;
    eula = true;
    environmentFile = config.sops.secrets.minecraft.path;
  };

  networking.firewall = {
    allowedTCPPorts = [ 25565 ];
    allowedUDPPorts = [ 25565 19132 ];
  };
}
