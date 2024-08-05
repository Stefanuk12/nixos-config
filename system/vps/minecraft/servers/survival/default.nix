{ nixpkgs, lib, pkgs, inputs, ... }:

let
  mcVersion = "1.21";
  fabricVersion = "0.16.0";
  serverVersion = lib.replaceStrings ["."] ["_"] "fabric-${mcVersion}";
  allowUnfreesP = pkg: builtins.elem (lib.getName pkg) [
    "minecraft-server"
  ];
in { 
  nixpkgs.config.allowUnfreePredicate = allowUnfreesP;
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  services.minecraft-servers.servers.survival = {
    enable = true;
    enableReload = false;
    package = pkgs.fabricServers.${serverVersion}.override {loaderVersion = fabricVersion;};
    jvmOpts = ((import ../../aikar-flags.nix) "2G") + "-Dpaper.disableChannelLimit=true";
    serverProperties = {
      server-port = 25565;
    };
    symlinks = {
      mods = pkgs.linkFarmFromDrvs "mods" (builtins.attrValues {
        FabricApi = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/EY5IAcV9/fabric-api-0.101.2%2B1.21.jar";
          sha512 = "aff4569ae74fbcf2f19874b56ea9a811a9b2aee217641724b0ea6d764aa9e3c756becc7908c9bc6ac3fc3b613aad235f62188325b1d7439d23cb9d2c69d3bad8";
        };
      });
    };
  };
}
