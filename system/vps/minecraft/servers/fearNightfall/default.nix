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
    url = "https://mediafilez.forgecdn.net/files/6109/390/Fear_Nightfall_Remains_of_Chaos_Server_Pack_v1.0.10.zip";
    hash = "sha256-cBbvPeRT1m0jTERPFI9Jk4nbr2ep9++LvrY7wzIKHXk=";
    extension = "zip";
    stripRoot = false;
  };
  customPkgs = import ../../../../../customPkgs { inherit pkgs; };
  overlays = [
    (self: super: {
      forgeServers = customPkgs.forgeServers;
    })
  ];
  pkgs_graalvm = import (pkgs.fetchFromGitHub {
    owner = "NixOS";
    repo = "nixpkgs";
    rev = "a343533bccc62400e8a9560423486a3b6c11a23b";
    hash = "sha256-TofHtnlrOBCxtSZ9nnlsTybDnQXUmQrlIleXF1RQAwQ=";
  }) {
    inherit (pkgs) system;
  };
in {
  nixpkgs.config.allowUnfreePredicate = allowUnfreesP;
  nixpkgs.overlays = overlays;
  imports = [
    inputs.nix-minecraft.nixosModules.minecraft-servers
  ];

  networking.firewall.allowedUDPPorts = [ 24454 ];

  services.minecraft-servers.servers.fearNightfallNew = {
    enable = true;
    enableReload = true;
    package = pkgs.forgeServers.${serverVersion}.override {
      loaderVersion = forgeVersion;
      jre_headless = pkgs_graalvm.graalvm-ce;
    };
    jvmOpts = ((import ../../aikar-flags.nix) "6G") + "-Dpaper.disableChannelLimit=true";
    serverProperties = {
      server-port = 25565;
      max-tick-time = -1;
    };
    files = {
      "mods" = "${modpack}/mods";
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
      "defaultconfigs" = "${modpack}/defaultconfigs";
      "modernfix" = "${modpack}/modernfix";
    };
  };
}
