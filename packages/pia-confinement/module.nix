{ piaSrc }:
{ config, lib, pkgs, ... }:

let
  cfg = config.services.pia-confinement;
  ns = cfg.namespace;
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
          environment = {
            HOME = "/home/${qbt.user}";
            XDG_RUNTIME_DIR = "/run/user/${toString qbt.uid}";
            WAYLAND_DISPLAY = qbt.waylandDisplay;
            DISPLAY = ":0";
            DBUS_SESSION_BUS_ADDRESS = "unix:path=/run/user/${toString qbt.uid}/bus";
            QT_QPA_PLATFORM = "wayland;xcb";
          };
        };

        security.polkit.extraConfig = ''
          polkit.addRule(function(action, subject) {
            if (action.id == "org.freedesktop.systemd1.manage-units" &&
                action.lookup("unit") == "qbittorrent.service" &&
                subject.user == "${qbt.user}") {
              return polkit.Result.YES;
            }
          });
        '';
      }
    ))
  ]);
}
