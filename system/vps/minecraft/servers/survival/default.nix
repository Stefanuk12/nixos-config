{ nixpkgs, lib, pkgs, inputs, ... }:

let
  mcVersion = "1.20.1";
  fabricVersion = "0.15.7";
  serverVersion = lib.replaceStrings ["."] ["_"] "fabric-${mcVersion}";
  allowUnfreesP = pkg: builtins.elem (lib.getName pkg) [
    "minecraft-server-${mcVersion}"
  ];
in { 
  nixpkgs.config.allowUnfreePredicate = allowUnfreesP;
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  services.minecraft-servers.servers.survival = {
    enable = true;
    enableReload = true;
    package = pkgs.fabricServers.${serverVersion}.override {loaderVersion = fabricVersion;};
    jvmOpts = ((import ../../aikar-flags.nix) "2G") + "-Dpaper.disableChannelLimit=true";
    serverProperties = {
      server-port = 25565;
    };
    symlinks = {
      mods = pkgs.linkFarmFromDrvs "mods" (builtins.attrValues {
        FabricApi = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/YG53rBmj/fabric-api-0.92.0%2B1.20.1.jar";
          sha512 = "53ce4cb2bb5579cef37154c928837731f3ae0a3821dd2fb4c4401d22d411f8605855e8854a03e65ea4f949dfa0e500ac1661a2e69219883770c6099b0b28e4fa";
        };
      });
    };
  };
}
