{ nixpkgs, lib, pkgs, inputs, config, ... }:

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
      level-seed = "6856302969725317931";
    };
    path = [
      "${pkgs.git}"
      "${pkgs.git-lfs}"
    ];
    files = {
      "config/Discord-Integration.toml".value = {
        general = {
          botToken = "@BOT_TOKEN@";
          botChannel = "1270005531813089321";
        };
        linking = {
          whitelistMode = true;
        };
      };
    };
    symlinks = {
      mods = pkgs.linkFarmFromDrvs "mods" (builtins.attrValues {
        FabricApi = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/P7dR8mSH/versions/EY5IAcV9/fabric-api-0.101.2%2B1.21.jar";
          sha512 = "aff4569ae74fbcf2f19874b56ea9a811a9b2aee217641724b0ea6d764aa9e3c756becc7908c9bc6ac3fc3b613aad235f62188325b1d7439d23cb9d2c69d3bad8";
        };
        Lithium = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/gvQqBUqZ/versions/my7uONjU/lithium-fabric-mc1.21-0.12.7.jar";
          sha512 = "91d78cf26f61876b1f5110e8aabb0189fe20fb669c2f2dd608416bce31c5c02eec9284ea418c405ab118562b5b8202c83154784bedf136f95727a86096e43430";
        };
        FerriteCore = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/uXXizFIs/versions/wmIZ4wP4/ferritecore-7.0.0-fabric.jar";
          sha512 = "0f2f9b5aebd71ef3064fc94df964296ac6ee8ea12221098b9df037bdcaaca7bccd473c981795f4d57ff3d49da3ef81f13a42566880b9f11dc64645e9c8ad5d4f";
        };
        # AntiXray = pkgs.fetchurl {
        #   url = "https://cdn.modrinth.com/data/sml2FMaA/versions/ygME0nWQ/antixray-fabric-1.4.4%2B1.21.jar";
        #   sha512 = "9456a6a468283d7b4a0f6d03e6a184bcd9d58c839d0eb65c535b130ae0fd1311b9baa51b713da408e667cbbb7e1bfb4e6d631c878a217ea71405c3e6d6463385";
        # };
        Lithosphere = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/iv9jp2k9/versions/7mWcbA0m/lithosphere-1.2.jar";
          sha512 = "297b7aedca66d6180bab4922a9e9ce0ba9fd74a83ac3e84a2f9958dc45a19eb4e1d5f27b6b5e52ce07547e7d074cbd8b01f4f3636ed7b10f8f248665112f3cc1";
        };
        Chunky = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/fALzjamp/versions/dPliWter/Chunky-1.4.16.jar";
          sha512 = "7e862f4db563bbb5cfa8bc0c260c9a97b7662f28d0f8405355c33d7b4100ce05378b39ed37c5d75d2919a40c244a3011bb4ba63f9d53f10d50b11b32656ea395";
        };
        Sparky = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/l6YH9Als/versions/KYGTUMOq/spark-1.10.73-fabric.jar";
          sha512 = "ddc0f8dfefc2006cbe56b397b8c5d7d5532763f3a67dc3f875a300428085a1eb5fa8963624eaf2e9b68bd65ad265c75bd55296af05141de2c1bc23fbd2818254";
        };
        GeyserMC = pkgs.fetchurl {
          url = "https://download.geysermc.org/v2/projects/geyser/versions/latest/builds/latest/downloads/fabric";
          sha512 = "977e7da25fb134fa4647458bc1f486db21251a6ce3f443bd2b58a8c7540c3c1a6c70728dccbcb54511f012300e80e09d04eef24705fcda96ee19d09f9d02c886";
        };
        ModsCommand = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/PExmWQV8/versions/CSPwc34g/mods-command-mc1.21-1.1.7.jar";
          sha512 = "3549e36dccbbe71171bc35c93f53c00743a4647435377f7348a37deb15442d44a57378acbc8563fea3d7924fa02f218fe89102db8a11b36af173711af41510f0";
        };
        Fastback = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/ZHKrK8Rp/versions/YtkZmwLO/fastback-0.19.0%2B1.21-fabric.jar";
          sha512 = "2fd8d0121fd4c550b20c47b2e87deef72b09268e1fae671126f24f494ab886a964aa7f34c4a30526e5fe171fe4a74948e047c250a69c0832f7e93ec47852cf42";
        };
        DiscordIntegration = pkgs.fetchurl {
          url = "https://cdn.modrinth.com/data/rbJ7eS5V/versions/I3kp6jxL/dcintegration-fabric-3.0.7.2-1.21.jar";
          sha512 = "648acc554924638c8d06563d3ade0f7096b114c5429cafed32ae1653bf21f99b689a8f696dffa3d0e5417447b99c1fba55e48d0f6730958896f5a2d015b9b9e9";
        };
      });
    };
  };
}
