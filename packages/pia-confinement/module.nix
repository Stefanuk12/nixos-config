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

  # unitTest is a JS expression over `unit`, so callers can match a template's instances.
  manageUnitRule = user: unitTest: ''
    polkit.addRule(function(action, subject) {
      if (action.id != "org.freedesktop.systemd1.manage-units" ||
          subject.user != "${user}") {
        return;
      }
      var unit = action.lookup("unit");
      if (${unitTest}) {
        return polkit.Result.YES;
      }
    });
  '';

  regionFile = "/var/lib/pia/region";
  runtimeDir = "/run/pia";

  confinedUnits =
    lib.optional cfg.confinedApps.qbittorrent.enable "qbittorrent.service"
    ++ lib.optional cfg.confinedApps.helium.enable "helium-vpn.service";
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

        This is only the boot default: `pia-region` writes ${regionFile} at
        runtime and that wins until cleared with `pia-region auto`.
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

    regionSwitcher = {
      enable = lib.mkEnableOption "the `pia-region` CLI for changing region without a rebuild";

      user = lib.mkOption {
        type = lib.types.str;
        description = "User allowed to drive the switch (via polkit, no password).";
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
          RuntimeDirectory = "pia";
          RuntimeDirectoryPreserve = true;
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

          # Resolved here rather than baked into the unit, so pia-region can change it by
          # writing the file and restarting us. Empty means lowest-latency auto-select.
          region=${lib.escapeShellArg (if cfg.region == null then "" else cfg.region)}
          if [ -s ${regionFile} ]; then
            region=$(cat ${regionFile})
          fi

          # run_setup.sh runs non-interactively with AUTOCONNECT=true (lowest-latency region) or AUTOCONNECT=false + PREFERRED_REGION=<id>, else it prompts.
          if [ -n "$region" ]; then
            export AUTOCONNECT=false PREFERRED_REGION="$region"
          else
            export AUTOCONNECT=true
          fi

          PIA_CONNECT=false \
          PIA_PF=false \
          PIA_DNS=true \
          VPN_PROTOCOL=wireguard \
          DISABLE_IPV6=yes \
          MAX_LATENCY=${cfg.maxLatency} \
          PIA_CONF_PATH=${cfg.confPath} \
            ./run_setup.sh

          chmod 600 ${cfg.confPath}

          # World-readable so `pia-region` can report state without root.
          printf '%s\n' "''${region:-auto}" > ${runtimeDir}/region
          sed -n 's/^Endpoint *= *\([^:]*\).*/\1/p' ${cfg.confPath} > ${runtimeDir}/endpoint
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

        security.polkit.extraConfig = manageUnitRule qbt.user ''unit == "qbittorrent.service"'';
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

        security.polkit.extraConfig = manageUnitRule hlm.user ''unit == "helium-vpn.service"'';
      }
    ))

    (lib.mkIf cfg.regionSwitcher.enable (
      let
        serverList = "https://serverlist.piaservers.net/vpninfo/servers/v6";

        cli = pkgs.writeShellScriptBin "pia-region" ''
          set -eu
          PATH=${lib.makeBinPath (with pkgs; [ coreutils curl jq gawk systemd ])}

          # The serverlist is JSON on line 1 followed by a detached signature.
          regions() { curl -sf --max-time 15 ${serverList} | head -1; }

          status() {
            printf 'region:   %s\n' "$(cat ${runtimeDir}/region 2>/dev/null || echo 'unknown (pia-wg-gen has not run)')"
            endpoint=$(cat ${runtimeDir}/endpoint 2>/dev/null || true)
            if [ -n "$endpoint" ]; then
              name=$(regions | jq -r --arg ip "$endpoint" \
                '.regions[] | select(any(.servers.wg[]?; .ip == $ip)) | .name' | head -1)
              printf 'endpoint: %s%s\n' "$endpoint" "''${name:+  ($name)}"
            fi
          }

          switch() {
            target=$1
            if [ "$target" != auto ]; then
              # Validate before tearing anything down; also keeps the instance name sane.
              case "$target" in
                *[!a-z0-9_-]*) echo "pia-region: invalid region id '$target'" >&2; exit 1 ;;
              esac
              if ! regions | jq -e --arg id "$target" 'any(.regions[]; .id == $id)' >/dev/null; then
                echo "pia-region: no such region '$target' — see 'pia-region list'" >&2
                exit 1
              fi
            fi

            echo "pia-region: switching to $target (this takes a moment)..." >&2
            if ! systemctl start "pia-region@$target.service"; then
              echo "pia-region: switch failed — journalctl -u pia-region@$target.service" >&2
              exit 1
            fi
            status
          }

          case "''${1-}" in
            "" | status) status ;;
            list)
              regions | jq -r '.regions[] | "\(.id)|\(.name)|\(if .port_forward then "PF" else "" end)"' \
                | sort | awk -F'|' '{ printf "%-28s %-4s %s\n", $1, $3, $2 }'
              ;;
            -h | --help)
              echo "usage: pia-region [status | list | auto | <region-id>]"
              ;;
            *) switch "$1" ;;
          esac
        '';
      in
      {
        environment.systemPackages = [ cli ];

        systemd.services."pia-region@" = {
          description = "Switch the PIA tunnel to region %i";
          path = with pkgs; [ coreutils systemd ];
          serviceConfig = {
            Type = "oneshot";
            StateDirectory = "pia";
            StateDirectoryMode = "0750";
            TimeoutStartSec = "6min";
          };
          # Via scriptArgs, not the script body: systemd expands %i in unit directives only,
          # and NixOS puts `script` in a store file where it would stay literal.
          scriptArgs = "%i";
          script = ''
            set -euo pipefail
            region=$1
            case "$region" in
              *[!a-z0-9_-]*) echo "invalid region id" >&2; exit 1 ;;
            esac

            if [ "$region" = auto ]; then
              rm -f ${regionFile}
            else
              printf '%s\n' "$region" > ${regionFile}
            fi

            # Restarting ${ns} kills anything bound to it, so put back whatever was up.
            running=""
            for unit in ${lib.escapeShellArgs confinedUnits}; do
              if systemctl is-active --quiet "$unit"; then running="$running $unit"; fi
            done

            # pia.service Requires= won't re-run a RemainAfterExit oneshot that is already
            # active, so the generator has to be restarted explicitly and first.
            systemctl restart pia-wg-gen.service
            systemctl restart ${ns}.service

            for unit in $running; do systemctl start "$unit" || true; done
          '';
        };

        security.polkit.extraConfig =
          manageUnitRule cfg.regionSwitcher.user ''unit.indexOf("pia-region@") == 0'';
      }
    ))
  ]);
}
