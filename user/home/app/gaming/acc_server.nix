{ config, pkgs, ... }:

let
  wine = pkgs.wineWow64Packages.stable;
  serverDir = "${config.home.homeDirectory}/.local/share/Steam/steamapps/common/Assetto Corsa Competizione Dedicated Server/server";

  toJSON = name: value: pkgs.writeText name (builtins.toJSON value);

  cfg = {
    "configuration.json" = toJSON "configuration.json" {
      udpPort = 9231;
      tcpPort = 9232;
      maxConnections = 16;
      lanDiscovery = 1;
      registerToLobby = 0;
      configVersion = 1;
    };

    "settings.json" = toJSON "settings.json" {
      serverName = "Stefan's LAN";
      password = "";
      adminPassword = "admin";
      spectatorPassword = "";
      carGroup = "FreeForAll";
      trackMedalsRequirement = 0;
      safetyRatingRequirement = -1;
      racecraftRatingRequirement = -1;
      maxCarSlots = 16;
      isRaceLocked = 0;
      allowAutoDQ = 0;
      shortFormationLap = 1;
      formationLapType = 3;
      ignorePrematureDisconnects = 1;
      configVersion = 1;
    };

    "event.json" = toJSON "event.json" {
      track = "monza";
      preRaceWaitingTimeSeconds = 80;
      sessionOverTimeSeconds = 120;
      ambientTemp = 22;
      cloudLevel = 0.1;
      rain = 0.0;
      weatherRandomness = 1;
      configVersion = 1;
      sessions = [
        { hourOfDay = 14; dayOfWeekend = 1; timeMultiplier = 1; sessionType = "P"; sessionDurationMinutes = 20; }
        { hourOfDay = 14; dayOfWeekend = 2; timeMultiplier = 1; sessionType = "Q"; sessionDurationMinutes = 10; }
        { hourOfDay = 15; dayOfWeekend = 3; timeMultiplier = 1; sessionType = "R"; sessionDurationMinutes = 20; }
      ];
    };
  };

  accServer = pkgs.writeShellApplication {
    name = "acc-server";
    runtimeInputs = [ wine ];
    text = ''
      export WINEPREFIX="$HOME/.local/share/wineprefixes/acc-server"
      export WINEDEBUG=-all
      export WINEDLLOVERRIDES="mscoree,mshtml="

      server="${serverDir}"
      if [ ! -f "$server/accServer.exe" ]; then
        echo "ACC Dedicated Server isn't installed — install it from Steam > Library > Tools" >&2
        exit 1
      fi

      mkdir -p "$server/cfg"
      ${builtins.concatStringsSep "\n" (
        map (n: ''install -m644 ${cfg.${n}} "$server/cfg/${n}"'') (builtins.attrNames cfg)
      )}

      cd "$server"
      exec wine accServer.exe
    '';
  };
in
{
  home.packages = [ accServer ];

  systemd.user.services.acc-server = {
    Unit.Description = "Assetto Corsa Competizione dedicated server";
    Service = {
      ExecStart = "${accServer}/bin/acc-server";
      Restart = "on-failure";
    };
  };
}
