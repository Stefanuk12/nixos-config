{ piaSrc }:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.pia-confinement;
  ns = cfg.namespace;

  sessionEnv = app: {
    HOME = "/home/${app.user}";
    XDG_RUNTIME_DIR = "/run/user/${toString app.uid}";
    WAYLAND_DISPLAY = app.waylandDisplay;
    DISPLAY = ":0";
    DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString app.uid}/bus";
  };

  manageUnitRule = user: unit: ''
    polkit.addRule(function(action, subject) {
      if (action.id == "org.freedesktop.systemd1.manage-units" &&
          action.lookup("unit") == "${unit}" &&
          subject.user == "${user}") {
        return polkit.Result.YES;
      }
    });
  '';
in
{
  options.services.pia-confinement = {
    enable = lib.mkEnableOption "PIA WireGuard tunnel confined to a network namespace";

    namespace = lib.mkOption {
      type = lib.types.str;
      default = "pia";
      description = "Name of the network namespace that vpn-confinement creates.";
    };

    region = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "us_east";
      description = ''
        PIA region code passed to manual-connections as PREFERRED_REGION.
        Set to null to let manual-connections pick the lowest-latency region
        below `maxLatency` automatically.
      '';
    };

    maxLatency = lib.mkOption {
      type = lib.types.str;
      default = "0.05";
      example = "0.2";
      description = ''
        Max acceptable latency in seconds when auto-selecting a region
        (region = null). Ignored when region is set explicitly. PIA's default
        is 50 ms; raise this if auto-selection fails on a slow connection.
      '';
    };

    credentialsFile = lib.mkOption {
      type = lib.types.str;
      example = "/run/pia-creds/creds";
      description = ''
        Path to a file containing PIA credentials. Two lines:
          Line 1: PIA username (e.g. p1234567)
          Line 2: PIA password

        Read at service-start time via systemd LoadCredential. The path can
        be created at runtime by another systemd unit (use Requires=/After= on
        pia-wg-gen.service); it does not need to exist at evaluation time.
      '';
    };

    confPath = lib.mkOption {
      type = lib.types.str;
      default = "/var/lib/pia/pia.conf";
      description = "Where the generated wg-quick conf is written, and what vpn-confinement consumes.";
    };

    refreshTimer = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = "weekly";
      example = "monthly";
      description = "systemd OnCalendar value for the refresh timer. Set null to disable.";
    };

    confinedApps.qbittorrent = {
      enable = lib.mkEnableOption "qbittorrent system service confined to the PIA namespace";

      user = lib.mkOption {
        type = lib.types.str;
        description = "User to run qbittorrent as. Must have a working desktop session.";
      };

      uid = lib.mkOption {
        type = lib.types.int;
        default = 1000;
        description = "UID of the user above (for XDG_RUNTIME_DIR / DBus path).";
      };

      waylandDisplay = lib.mkOption {
        type = lib.types.str;
        default = "wayland-1";
        description = "Name of the user session's wayland socket (check `ls /run/user/<uid>/`).";
      };
    };

    confinedApps.helium = {
      enable = lib.mkEnableOption "a second Helium instance, confined to the PIA namespace";

      user = lib.mkOption {
        type = lib.types.str;
        description = "User to run Helium as. Must have a working desktop session.";
      };

      uid = lib.mkOption {
        type = lib.types.int;
        default = 1000;
        description = "UID of the user above (for XDG_RUNTIME_DIR / DBus path).";
      };

      waylandDisplay = lib.mkOption {
        type = lib.types.str;
        default = "wayland-1";
        description = "Name of the user session's wayland socket (check `ls /run/user/<uid>/`).";
      };

      package = lib.mkOption {
        type = lib.types.package;
        default = pkgs.helium;
        defaultText = "pkgs.helium";
        description = "Helium package to run. Should match the unconfined instance's package.";
      };

      profileDir = lib.mkOption {
        type = lib.types.str;
        default = ".config/net.imput.helium-vpn";
        description = ''
          Profile directory, relative to the user's home. MUST differ from the unconfined
          instance's profile: Chromium hands a launch off to whichever process already holds
          that profile's singleton socket, so a shared profile would silently route the
          confined launch into the unconfined browser.
        '';
      };
    };
  };

  config = lib.mkIf cfg.enable (lib.mkMerge [
    {
      systemd.services.pia-wg-gen = {
        description = "Generate PIA WireGuard config";
        before = [ "${ns}.service" ];
        wantedBy = [ "${ns}.service" ];
        after = [ "network-online.target" ];
        wants = [ "network-online.target" ];
        path = with pkgs; [ bash curl jq gawk wireguard-tools iproute2 util-linux ];
        serviceConfig = {
          Type = "oneshot";
          RemainAfterExit = true;
          StateDirectory = "pia";
          StateDirectoryMode = "0750";
          WorkingDirectory = "/var/lib/pia";
          TimeoutStartSec = "5min";
          Restart = "on-failure";
          RestartSec = "30s";
          LoadCredential = [ "pia_creds:${cfg.credentialsFile}" ];
        };
        unitConfig = {
          StartLimitIntervalSec = "10min";
          StartLimitBurst = 20;
        };
        script = ''
          set -euo pipefail

          curl -sfL --max-time 5 --retry 60 --retry-delay 5 \
            --retry-connrefused --retry-all-errors \
            https://www.privateinternetaccess.com/ >/dev/null

          PIA_USER=$(sed -n '1p' "$CREDENTIALS_DIRECTORY/pia_creds")
          PIA_PASS=$(sed -n '2p' "$CREDENTIALS_DIRECTORY/pia_creds")
          if [ -z "$PIA_USER" ] || [ -z "$PIA_PASS" ]; then
            echo "ERROR: credentialsFile must have username on line 1, password on line 2" >&2
            exit 1
          fi
          export PIA_USER PIA_PASS

          # manual-connections uses relative paths + a hardcoded /opt/piavpn-manual state dir, so copy to a writable scratch dir and rewrite the path.
          work=$(mktemp -d)
          trap 'rm -rf "$work"' EXIT
          cp -rT ${piaSrc} "$work"
          chmod -R u+w "$work"
          mkdir -p "$work/state"
          grep -rIlZ --include='*.sh' /opt/piavpn-manual "$work" \
            | xargs -0 -r sed -i "s|/opt/piavpn-manual|$work/state|g"
          cd "$work"

          # run_setup.sh runs non-interactively with AUTOCONNECT=true (lowest-latency region) or AUTOCONNECT=false + PREFERRED_REGION=<id>, else it prompts.
          PIA_CONNECT=false \
          PIA_PF=false \
          PIA_DNS=true \
          VPN_PROTOCOL=wireguard \
          DISABLE_IPV6=yes \
          MAX_LATENCY=${cfg.maxLatency} \
          ${if cfg.region == null
            then "AUTOCONNECT=true"
            else "AUTOCONNECT=false PREFERRED_REGION=${cfg.region}"} \
          PIA_CONF_PATH=${cfg.confPath} \
            ./run_setup.sh

          chmod 600 ${cfg.confPath}
        '';
      };

      systemd.timers.pia-wg-gen = lib.mkIf (cfg.refreshTimer != null) {
        description = "Refresh PIA WireGuard config";
        wantedBy = [ "timers.target" ];
        timerConfig = {
          OnCalendar = cfg.refreshTimer;
          Persistent = true;
        };
      };

      # Fail-closed: namespace won't come up if conf gen fails.
      systemd.services.${ns} = {
        requires = [ "pia-wg-gen.service" ];
        after = [ "pia-wg-gen.service" ];
      };

      vpnNamespaces.${ns} = {
        enable = true;
        wireguardConfigFile = cfg.confPath;
      };
    }

    (lib.mkIf cfg.confinedApps.qbittorrent.enable (
      let
        qbt = cfg.confinedApps.qbittorrent;

        launcher = pkgs.writeShellScriptBin "qbittorrent" ''
          set -eu
          if ! ${pkgs.systemd}/bin/systemctl is-active --quiet qbittorrent.service; then
            ${pkgs.systemd}/bin/systemctl start qbittorrent.service
            sleep 2
          fi
          [ "$#" -eq 0 ] && exit 0
          exec ${pkgs.qbittorrent}/bin/qbittorrent "$@"
        '';

        qbittorrent-vpn = pkgs.symlinkJoin {
          name = "qbittorrent-vpn";
          paths = [ pkgs.qbittorrent ];
          postBuild = ''
            rm $out/bin/qbittorrent
            ln -s ${launcher}/bin/qbittorrent $out/bin/qbittorrent
          '';
        };
      in
      {
        environment.systemPackages = [ qbittorrent-vpn ];

        systemd.services.qbittorrent = {
          description = "qBittorrent (confined to ${ns} netns)";
          vpnConfinement = {
            enable = true;
            vpnNamespace = ns;
          };
          serviceConfig = {
            Type = "simple";
            User = qbt.user;
            Group = "users";
            Restart = "on-failure";
            RestartSec = "5s";
            ExecStart = "${pkgs.qbittorrent}/bin/qbittorrent";
          };
          environment = sessionEnv qbt // {
            QT_QPA_PLATFORM = "wayland;xcb";
          };
        };

        security.polkit.extraConfig = manageUnitRule qbt.user "qbittorrent.service";
      }
    ))

    (lib.mkIf cfg.confinedApps.helium.enable (
      let
        hlm = cfg.confinedApps.helium;
        profile = "/home/${hlm.user}/${hlm.profileDir}";
        socket = "${profile}/SingletonSocket";
        handoff = ''${hlm.package}/bin/helium --user-data-dir=${profile}'';

        launcher = pkgs.writeShellScriptBin "helium-vpn" ''
          set -eu

          # With the socket present, this exec only forwards the command line to the confined
          # process and exits; without it, the same exec would open the profile out here,
          # unconfined. So never reach it until the service is actually up.
          if [ ! -S ${socket} ]; then
            ${pkgs.systemd}/bin/systemctl start helium-vpn.service
            for _ in $(${pkgs.coreutils}/bin/seq 100); do
              [ -S ${socket} ] && break
              ${pkgs.coreutils}/bin/sleep 0.1
            done
            if [ ! -S ${socket} ]; then
              echo "helium-vpn.service did not come up; is the ${ns} namespace running?" >&2
              exit 1
            fi
            # The service opened its own startup window, so a bare launch is already served.
            if [ "$#" -eq 0 ]; then exit 0; fi
          fi

          exec ${handoff} "$@"
        '';

        desktopItem = pkgs.makeDesktopItem {
          name = "helium-vpn";
          desktopName = "Helium (VPN)";
          genericName = "Web Browser";
          exec = "${launcher}/bin/helium-vpn %U";
          icon = "${hlm.package}/share/icons/hicolor/256x256/apps/helium.png";
          categories = [ "Network" "WebBrowser" ];
          startupWMClass = "helium-vpn";
          # No mimeTypes: this must never win the default http/https handler.
        };
      in
      {
        environment.systemPackages = [ launcher desktopItem ];

        systemd.services.helium-vpn = {
          description = "Helium (confined to ${ns} netns)";
          vpnConfinement = {
            enable = true;
            vpnNamespace = ns;
          };
          serviceConfig = {
            Type = "simple";
            User = hlm.user;
            Group = "users";
            Restart = "no";
            ExecStart = "${handoff} --class=helium-vpn";
          };
          environment = sessionEnv hlm // {
            NIXOS_OZONE_WL = "1";
          };
        };

        security.polkit.extraConfig = manageUnitRule hlm.user "helium-vpn.service";
      }
    ))
  ]);
}
