{ inputs, config, lib, pkgs, ... }:

{
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    # ./servers/fearNightfall
  ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  sops.secrets.minecraft = {
    owner = "minecraft";
    group = "minecraft";
    mode = "0400";
    sopsFile = ../../../secrets/vps/minecraft.yaml;
  };

  programs.git = {
    enable = true;
    lfs.enable = true;
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
