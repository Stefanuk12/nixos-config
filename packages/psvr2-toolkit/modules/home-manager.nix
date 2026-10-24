{
  config,
  lib,
  pkgs,
  ...
}:

let
  cfg = config.programs.psvr2-toolkit;

  ignitionDir = "${cfg.ignition.package}/lib/ignition";
  toolkitDir = "${cfg.driver.package}/lib/psvr2-toolkit/win64";
  toolkitFiles = [
    "driver_playstation_vr2.dll"
    "psvr2_toolkit_capi.dll"
    "libcrossipc.dll"
    "libcrossipc.so"
    "libpsvr2_toolkit_capi.so"
    "libusb-1.0.dll"
  ];

  scalar = lib.types.oneOf [
    lib.types.bool
    lib.types.int
    lib.types.float
    lib.types.str
  ];

  steamvrSettings = pkgs.writeText "psvr2-steamvr-settings.json" (
    builtins.toJSON (
      lib.recursiveUpdate {
        steamvr = {
          enableLinuxVulkanAsync = true;
          useFacetRenderer = true;
        };
      } cfg.steamvrSettings
    )
  );

  ignitionJson = pkgs.writeText "ignition.json" (
    builtins.toJSON {
      server_exe = "${ignitionDir}/ignition_server.exe";
      driver_dll = "../win64/driver_playstation_vr2.dll";
      wine_cmd = [ "./launch_serverhelper.sh" ];
      wait_for_debugger = false;
    }
  );

  # Upstream's launch_serverhelper.sh with the Proton build and prefix pinned; the shim runs it
  # inside the Steam runtime with cwd = bin/linux64.
  launchServerHelper = pkgs.writeScript "launch_serverhelper.sh" ''
    #!/bin/bash
    unset SteamGameId
    export PROTONVERSION=${lib.escapeShellArg cfg.protonVersion}
    export PROTONPREFIX="${cfg.protonPrefix}"
    ./proton run reg import ./wine_psvr2_hidraw.reg
    ./proton run "$@"
  '';

  paths = ''
    steam="${cfg.steamPath}"
    driver="$steam/steamapps/common/PlayStation VR2 App/SteamVR_Plug-In"
    linux64="$driver/bin/linux64"
    win64="$driver/bin/win64"
    vrpath="$HOME/.config/openvr/openvrpaths.vrpath"
    vrsettings="$steam/config/steamvr.vrsettings"
    cur="$win64/driver_playstation_vr2.dll"
    orig="$win64/driver_playstation_vr2_orig.dll"
    state="$win64/.psvr2-toolkit-installed"

    if pgrep -x 'vrserver|vrmonitor' >/dev/null; then
      echo "psvr2-toolkit: SteamVR is running; quit it first" >&2
      exit 1
    fi

    is_toolkit() {
      local sha
      sha=$(sha256sum "$1" | cut -d' ' -f1)
      [ "$sha" = "$(sha256sum ${toolkitDir}/driver_playstation_vr2.dll | cut -d' ' -f1)" ] \
        || [ "$sha" = "$(cat "$state" 2>/dev/null || true)" ]
    }

    edit_json() {
      local file="$1" tmp
      shift
      tmp=$(mktemp "$file.XXXXXX")
      if jq "$@" > "$tmp"; then
        chmod 644 "$tmp"
        mv -f "$tmp" "$file"
      else
        rm -f "$tmp"
        return 1
      fi
    }
  '';

  install = pkgs.writeShellApplication {
    name = "psvr2-toolkit-install";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      procps
    ];
    # jq programs keep their $vars in single quotes.
    excludeShellChecks = [ "SC2016" ];
    text = ''
      ${paths}

      if [ ! -f "$driver/driver.vrdrivermanifest" ]; then
        echo "psvr2-toolkit: PlayStation VR2 App not found at $driver" >&2
        echo "psvr2-toolkit: install it from Steam (app 2580190), then run psvr2-toolkit-install" >&2
        exit 1
      fi

      echo "[1/4] Ignition -> $linux64"
      mkdir -p "$linux64"
      ln -sfn ${ignitionDir}/libdriver_ignition.so "$linux64/driver_playstation_vr2.so"
      ln -sfn ${ignitionDir}/proton "$linux64/proton"
      ln -sfn ${ignitionDir}/wine_psvr2_hidraw.reg "$linux64/wine_psvr2_hidraw.reg"
      ln -sfn ${ignitionJson} "$linux64/ignition.json"
      ln -sfn ${launchServerHelper} "$linux64/launch_serverhelper.sh"

      echo "[2/4] PSVR2Toolkit -> $win64"
      mkdir -p "$win64"
      # Whatever is not a toolkit build is Sony's driver: a fresh install, or Steam restoring it.
      if [ -f "$cur" ] && ! is_toolkit "$cur"; then
        mv -f "$cur" "$orig"
      fi
      if [ ! -f "$orig" ]; then
        echo "psvr2-toolkit: no Sony driver_playstation_vr2.dll to wrap; verify the PlayStation VR2 App files in Steam" >&2
        exit 1
      fi
      for f in ${toString toolkitFiles}; do
        install -m644 ${toolkitDir}/"$f" "$win64/.$f.tmp"
        mv -f "$win64/.$f.tmp" "$win64/$f"
      done
      sha256sum ${toolkitDir}/driver_playstation_vr2.dll | cut -d' ' -f1 > "$state"

      echo "[3/4] register driver in $vrpath"
      if [ -d "$steam/steamapps/common/SteamVR" ]; then
        mkdir -p "$(dirname "$vrpath")"
        if [ -f "$vrpath" ]; then
          edit_json "$vrpath" --arg d "$driver" \
            '.external_drivers = ((.external_drivers // []) | if index($d) then . else . + [$d] end)' "$vrpath"
        else
          edit_json "$vrpath" -n --arg steam "$steam" --arg d "$driver" '{
            config: [$steam + "/config"],
            external_drivers: [$d],
            jsonid: "vrpathreg",
            log: [$steam + "/logs"],
            runtime: [$steam + "/steamapps/common/SteamVR"],
            version: 1
          }'
        fi
      else
        echo "psvr2-toolkit: SteamVR not installed (app 250820); driver not registered" >&2
      fi

      echo "[4/4] merge settings into $vrsettings"
      mkdir -p "$steam/config"
      if [ -f "$vrsettings" ]; then
        edit_json "$vrsettings" --slurpfile s ${steamvrSettings} '. * $s[0]' "$vrsettings"
      else
        edit_json "$vrsettings" . ${steamvrSettings}
      fi

      if [ ! -d "$steam/steamapps/common/${cfg.protonVersion}" ]; then
        echo "psvr2-toolkit: '${cfg.protonVersion}' is not installed; Ignition falls back to the newest Proton it finds" >&2
      fi
      if [ ! -e /etc/udev/rules.d/70-xrhardware.rules ]; then
        echo "psvr2-toolkit: 70-xrhardware.rules is missing; enable hardware.psvr2 in the NixOS config" >&2
      fi
      echo "psvr2-toolkit: done. Firmware must be 5.00+ (psvr2-updater shows the current one); set the play area with psvr2-unity-setup."
      echo "psvr2-toolkit: to test the Proton side by hand: cd \"$linux64\" && steam-run ./launch_serverhelper.sh cmd"
    '';
  };

  uninstall = pkgs.writeShellApplication {
    name = "psvr2-toolkit-uninstall";
    runtimeInputs = with pkgs; [
      coreutils
      jq
      procps
    ];
    # jq programs keep their $vars in single quotes.
    excludeShellChecks = [ "SC2016" ];
    text = ''
      ${paths}

      if [ -f "$orig" ]; then
        if [ -f "$cur" ] && ! is_toolkit "$cur"; then
          rm -f "$orig"
        else
          mv -f "$orig" "$cur"
        fi
      fi
      for f in ${toString (lib.remove "driver_playstation_vr2.dll" toolkitFiles)}; do
        rm -f "$win64/$f"
      done
      rm -f "$state"
      rm -rf "$linux64"
      if [ -f "$vrpath" ]; then
        edit_json "$vrpath" --arg d "$driver" '.external_drivers = ((.external_drivers // []) - [$d])' "$vrpath"
      fi
      echo "psvr2-toolkit: removed; $vrsettings was left as is"
    '';
  };

  mkPackage =
    file: description:
    lib.mkOption {
      type = lib.types.package;
      default = pkgs.callPackage file { };
      defaultText = lib.literalMD "the package built by this flake";
      inherit description;
    };
in
{
  options.programs.psvr2-toolkit = {
    enable = lib.mkEnableOption "PlayStation VR2 on SteamVR through Ignition and PSVR2Toolkit";

    steamPath = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/Steam";
      description = "Steam root holding steamapps/ and config/. Shell-expanded by the install scripts.";
    };

    protonVersion = lib.mkOption {
      type = lib.types.str;
      default = "Proton - Experimental";
      description = ''
        Directory name (under steamapps/common or compatibilitytools.d) of the Proton build that
        hosts the Windows driver. Upstream only supports Proton Experimental.
      '';
    };

    protonPrefix = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/ignition";
      description = ''
        STEAM_COMPAT_DATA_PATH for the driver host process; Proton creates the Wine prefix in
        pfx/ below it. Shell-expanded.
      '';
    };

    steamvrSettings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf scalar);
      default = { };
      example = lib.literalExpression ''
        {
          steamvr.preferredRefreshRate = 120;
          driver_gamepad.enable = false;
        }
      '';
      description = ''
        Section -> key -> value, merged into steamvr.vrsettings on top of the two Linux settings
        the driver needs (enableLinuxVulkanAsync, useFacetRenderer). Keys you don't declare are
        preserved. Re-applied on every activation; SteamVR must not be running then.
      '';
    };

    ignition.package = mkPackage ../pkgs/ignition.nix "Ignition build providing the Linux driver shim and Windows host.";
    driver.package = mkPackage ../pkgs/psvr2-toolkit-driver.nix "PSVR2Toolkit driver build for Ignition.";

    steamvrLinuxFixes = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the SteamVRLinuxFixes Vulkan layer (implicit; only acts inside vrcompositor).";
      };
      package = mkPackage ../pkgs/steamvr-linux-fixes.nix "SteamVRLinuxFixes layer package.";
    };

    playAreaSetup = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install psvr2-unity-setup, the play area / passthrough / eye calibration app.";
      };
      package = mkPackage ../pkgs/psvr2-unity-setup.nix "PSVR2Toolkit.UnitySetup package. Wrap it if the app must be pinned to a GPU.";
    };

    capiApps = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install the legacy IPC server for apps on the pre-experimental toolkit protocol.";
      };
      package = mkPackage ../pkgs/psvr2-toolkit-capi-apps.nix "PSVR2Toolkit CAPI apps package.";
    };

    updater = {
      enable = lib.mkOption {
        type = lib.types.bool;
        default = true;
        description = "Install psvr2-updater for reading and flashing headset firmware.";
      };
      package = mkPackage ../pkgs/psvr2-updater.nix "PSVR2Updater package.";
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      install
      uninstall
    ]
    ++ lib.optional cfg.steamvrLinuxFixes.enable cfg.steamvrLinuxFixes.package
    ++ lib.optional cfg.playAreaSetup.enable cfg.playAreaSetup.package
    ++ lib.optional cfg.capiApps.enable cfg.capiApps.package
    ++ lib.optional cfg.updater.enable cfg.updater.package;

    # Every switch, because a PlayStation VR2 App update puts Sony's DLL back over the toolkit's.
    home.activation.psvr2Toolkit = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${lib.getExe install} || true
    '';
  };
}
