{ nixpkgs, lib, pkgs, inputs, ... }:

let
  mcVersion = "1.20.1";
  forgeVersion = "47.3.12";
  serverVersion = lib.replaceStrings ["."] ["_"] "forge-${mcVersion}";
  allowUnfreesP = pkg: builtins.elem (lib.getName pkg) [
    "minecraft-server-${mcVersion}"
    "forge-loader"
  ];
  modpack = pkgs.fetchzip {
    url = "https://mediafilez.forgecdn.net/files/6109/374/Fear%20Nightfall%20Remains%20of%20Chaos-v1.0.10.zip";
    hash = "sha256-ec/M+0AOMkOPLoVG43Lxn20mo6kAQMuOpT8bUb1W/Oo=";
    extension = "zip";
    stripRoot = false;
  };
  customPkgs = import ../../../../../customPkgs { inherit pkgs; };
  overlays = [
    (self: super: {
      forgeServers = customPkgs.forgeServers;
    })
  ];
in {
  nixpkgs.config.allowUnfreePredicate = allowUnfreesP;
  nixpkgs.overlays = overlays;
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  networking.firewall.allowedUDPPorts = [ 24454 ];

  services.minecraft-servers.servers.survival = {
    enable = true;
    enableReload = true;
    package = pkgs.forgeServers.${serverVersion}.override {
      loaderVersion = forgeVersion;
      jre_headless = pkgs.jdk17;
    };
    jvmOpts = ((import ../../aikar-flags.nix) "2G") + "-Dpaper.disableChannelLimit=true";
    serverProperties = {
      server-port = 25565;
    };
    files = {
    };
    symlinks = {
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
      "mods" = "${modpack}/mods";
    };
  };
}
