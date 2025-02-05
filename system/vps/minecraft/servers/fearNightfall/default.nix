{ nixpkgs, lib, customPkgs, pkgs, inputs, ... }:

let
  mcVersion = "1.20.1";
  forgeVersion = "47.3.12";
  serverVersion = lib.replaceStrings ["."] ["_"] "forge-${mcVersion}";
  allowUnfreesP = pkg: builtins.elem (lib.getName pkg) [
    "minecraft-server-${mcVersion}"
  ];
  modpack = pkgs.fetchzip {
    url = "https://www.curseforge.com/api/v1/mods/887839/files/6109374/download";
    hash = "sha256-qizlevXTfRr5bqQM4u5dKfqV75fBpgjmxSprlwBHnC4=";
  };
in { 
  nixpkgs.config.allowUnfreePredicate = allowUnfreesP;
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  networking.firewall.allowedUDPPorts = [ 24454 ];

  services.minecraft-servers.servers.survival = {
    enable = true;
    enableReload = true;
    package = customPkgs.forgeServers.${serverVersion}.override {
      loaderVersion = forgeVersion;
      jre_headless = pkgs.jdk17;
    };
    jvmOpts = ((import ../../aikar-flags.nix) "2G") + "-Dpaper.disableChannelLimit=true";
    serverProperties = {
      server-port = 25565;
    };
    files = {
      "config" = "${modpack}/config";
      "config/Discord-Integration.toml".value = {
        general = {
          botToken = "@BOT_TOKEN@";
          botChannel = "1336084099869442079";
        };
        linking = {
          whitelistMode = true;
        };
      };
    };
    symlinks = {
      "mods" = "${modpack}/mods";
    };
  };
}
