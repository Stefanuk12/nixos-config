{ inputs, config, lib, ... }:

{
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
    ./servers/survival
  ];
  nixpkgs.overlays = [ inputs.nix-minecraft.overlay ];

  services.minecraft-servers = {
    enable = true;
    eula = true;
  };

  networking.firewall = {
    allowedTCPPorts = [ 25565 ];
    allowedUDPPorts = [ 25565 19132 ];
  };
}
