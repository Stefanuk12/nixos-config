{
  description = "Apple Notification Center Service for Linux";

  inputs = {
    nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

    ancs4linux-src = {
      url = "github:pzmarzly/ancs4linux";
      flake = false;
    };
  };

  outputs =
    {
      self,
      nixpkgs,
      ancs4linux-src,
    }:
    let
      supportedSystems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = nixpkgs.lib.genAttrs supportedSystems;

      mkPackage =
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
          python = pkgs.python3;
        in
        python.pkgs.buildPythonApplication {
          pname = "ancs4linux";
          # Date prefix gives monotonic ordering across commits.
          version = "unstable-${ancs4linux-src.lastModifiedDate or "19700101"}-${
            ancs4linux-src.shortRev or "dirty"
          }";
          pyproject = true;

          src = ancs4linux-src;

          build-system = [ python.pkgs.poetry-core ];

          nativeBuildInputs = with pkgs; [
            gobject-introspection
            wrapGAppsNoGuiHook
            python.pkgs.pythonRelaxDepsHook
          ];

          pythonRelaxDeps = [ "typer" ];

          dependencies = with python.pkgs; [
            pygobject3
            dbus-python
            bleak
            dasbus
            typer
          ];

          pythonImportsCheck = [
            "ancs4linux"
            "ancs4linux.advertising"
            "ancs4linux.observer"
          ];

          doCheck = false; # upstream has no test suite

          passthru.tests = {
            inherit (self.checks.${system}) module-test;
          };

          meta = {
            description = "Apple Notification Center Service for Linux";
            homepage = "https://github.com/pzmarzly/ancs4linux";
            license = pkgs.lib.licenses.mit;
            platforms = pkgs.lib.platforms.linux;
            mainProgram = "ancs4linux-observer";
          };
        };
    in
    {
      packages = forAllSystems (system: rec {
        ancs4linux = mkPackage system;
        default = ancs4linux;
      });

      formatter = forAllSystems (system: nixpkgs.legacyPackages.${system}.nixfmt-rfc-style);

      overlays.default = final: _prev: {
        ancs4linux = self.packages.${final.system}.ancs4linux;
      };

      devShells = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          default = pkgs.mkShell {
            inputsFrom = [ self.packages.${system}.ancs4linux ];
            packages = with pkgs; [ jq ];
          };
        }
      );

      # -------------------------------------------------------------------
      # Checks – `nix flake check` runs these.
      # -------------------------------------------------------------------
      checks = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        {
          module-test = pkgs.testers.nixosTest {
            name = "ancs4linux";

            nodes.machine =
              { ... }:
              {
                imports = [ self.nixosModules.default ];

                hardware.bluetooth.enable = true;

                services.ancs4linux = {
                  enable = true;
                  advertisingName = "test-machine";
                  user = "alice";
                };

                users.users.alice.isNormalUser = true;
              };

            testScript = ''
              machine.wait_for_unit("multi-user.target")

              # All four binaries are on PATH.
              for bin in [
                "ancs4linux-observer",
                "ancs4linux-advertising",
                "ancs4linux-ctl",
                "ancs4linux-desktop-integration",
              ]:
                  machine.succeed(f"which {bin}")

              # D-Bus policy was installed.
              machine.succeed(
                  "find /etc/dbus-1 -name 'ancs4linux.conf' | grep -q ."
              )

              # User services are present (we cannot start them without
              # real BLE hardware, but their unit files must exist).
              machine.succeed(
                  "su - alice -c 'systemctl --user list-unit-files'"
                  " | grep -q ancs4linux-advertising"
              )
            '';
          };
        }
      );

      # -------------------------------------------------------------------
      # NixOS module
      # -------------------------------------------------------------------
      nixosModules.default =
        {
          config,
          lib,
          pkgs,
          ...
        }:
        let
          cfg = config.services.ancs4linux;
          pkg = self.packages.${pkgs.stdenv.hostPlatform.system}.default;

          # ---------------------------------------------------------------
          # Shared hardening for every user service in the stack.
          #
          # All IPC goes through D-Bus (AF_UNIX); BLE is handled by BlueZ
          # in a separate process, so these services need no direct
          # hardware or network access.
          # ---------------------------------------------------------------
          commonServiceConfig = {
            Restart = "on-failure";
            RestartSec = 5;

            # -- Filesystem ------------------------------------------------
            NoNewPrivileges = true;
            ProtectSystem = "strict";
            ProtectHome = "read-only";
            PrivateTmp = true;
            UMask = "0077";

            # -- Kernel ----------------------------------------------------
            ProtectClock = true;
            ProtectHostname = true;
            ProtectKernelLogs = true;
            ProtectKernelTunables = true;
            ProtectKernelModules = true;
            ProtectControlGroups = true;

            # -- Capabilities & syscalls -----------------------------------
            CapabilityBoundingSet = "";
            SystemCallArchitectures = "native";
            # @system-service is a curated whitelist for typical daemons.
            # Strip privilege-escalation and resource-control families that
            # a notification-forwarding service has no use for.
            SystemCallFilter = [
              "@system-service"
              "~@privileged"
              "~@resources"
            ];

            # -- Network ---------------------------------------------------
            # D-Bus = AF_UNIX.  Add AF_NETLINK or AF_BLUETOOTH here if a
            # future upstream release opens sockets directly.
            RestrictAddressFamilies = [ "AF_UNIX" ];

            # -- Misc ------------------------------------------------------
            RestrictRealtime = true;
            LockPersonality = true;
            MemoryDenyWriteExecute = true; # safe for CPython (no JIT)
            RestrictNamespaces = true;
            RestrictSUIDSGID = true;
            RemoveIPC = true;

            # Flush Python output to the journal immediately.
            Environment = [ "PYTHONUNBUFFERED=1" ];
          };

          # ---------------------------------------------------------------
          # Helper: build a systemd *user* service for one component.
          #
          # `partOf` ties dependent lifetimes to the root advertising
          # service so a single `systemctl --user stop` tears everything
          # down.  Only the root service carries `wantedBy`; dependents
          # are pulled in via the Wants= chain.
          # ---------------------------------------------------------------
          mkAncsService =
            name:
            {
              execStart,
              after ? [ "dbus.service" ],
              wants ? [ ],
              bindsTo ? [ ],
              partOf ? [ ],
              wantedBy ? [ ],
              type ? "simple",
              extraServiceConfig ? { },
            }:
            {
              description = "ANCS4Linux ${name}";
              inherit
                after
                wants
                bindsTo
                partOf
                wantedBy
                ;
              serviceConfig =
                commonServiceConfig
                // {
                  Type = type;
                  ExecStart = execStart;
                }
                // extraServiceConfig;
            };
        in
        {
          options.services.ancs4linux = {
            enable = lib.mkEnableOption "ANCS4Linux (Apple notification forwarding)";

            advertisingName = lib.mkOption {
              type = lib.types.str;
              description = "BLE advertising name for this machine.";
            };

            hciAddress = lib.mkOption {
              type = with lib.types; nullOr str;
              default = null;
              example = "00:1A:7D:DA:71:13";
              description = ''
                HCI adapter address to use for BLE advertising.
                When `null` (the default), the first available adapter is
                auto-detected at runtime.
              '';
            };

            user = lib.mkOption {
              type = lib.types.str;
              description = "User to grant D-Bus ownership of ancs4linux.";
            };

            setupDelay = lib.mkOption {
              type = lib.types.ints.unsigned;
              default = 3;
              description = "Seconds to wait before BLE advertising setup.";
            };

            desktopIntegration = lib.mkOption {
              type = lib.types.bool;
              default = true;
              description = ''
                Whether to start the desktop-integration service that
                forwards Apple notifications to the freedesktop
                notification daemon.  Disable on headless machines.
              '';
            };

            package = lib.mkOption {
              type = lib.types.package;
              default = pkg;
              defaultText = lib.literalExpression "pkgs.ancs4linux";
              description = "The ancs4linux package to use.";
            };
          };

          config = lib.mkIf cfg.enable {
            assertions = [
              {
                assertion = config.hardware.bluetooth.enable;
                message = "services.ancs4linux requires hardware.bluetooth.enable = true.";
              }
              {
                assertion = config.users.users ? ${cfg.user} || cfg.user == "root";
                message = "services.ancs4linux.user '${cfg.user}' must be a declared user.";
              }
            ];

            environment.systemPackages = [ cfg.package ];

            services.dbus.packages =
              let
                dbusConf = pkgs.writeTextDir "share/dbus-1/system.d/ancs4linux.conf" ''
                  <!DOCTYPE busconfig PUBLIC
                    "-//freedesktop//DTD D-BUS Bus Configuration 1.0//EN"
                    "http://www.freedesktop.org/standards/dbus/1.0/busconfig.dtd">
                  <busconfig>
                    <policy user="${cfg.user}">
                      <allow own_prefix="ancs4linux"/>
                      <allow send_destination_prefix="ancs4linux"/>
                    </policy>
                    <policy context="default">
                      <allow send_destination_prefix="ancs4linux"/>
                    </policy>
                  </busconfig>
                '';
              in
              [ dbusConf ];

            systemd.user.services =
              let
                bin = lib.getExe' cfg.package;

                resolveAddress =
                  if cfg.hciAddress != null then
                    "address=${lib.escapeShellArg cfg.hciAddress}"
                  else
                    ''
                      address=$(
                        ${bin "ancs4linux-ctl"} get-all-hci \
                          | ${lib.getExe pkgs.jq} -r '.[0] // empty'
                      )

                      if [ -z "$address" ]; then
                        echo "error: no HCI adapter found" >&2
                        exit 1
                      fi
                    '';

                setupScript = pkgs.writeShellScript "ancs4linux-setup" ''
                  set -euo pipefail

                  ${resolveAddress}

                  echo "Using HCI adapter: $address"

                  ${bin "ancs4linux-ctl"} enable-advertising \
                    --hci-address "$address" \
                    --name ${lib.escapeShellArg cfg.advertisingName}
                '';

                rootUnit = "ancs4linux-advertising.service";
                setupUnit = "ancs4linux-setup.service";
                observerUnit = "ancs4linux-observer.service";
                desktopUnit = "ancs4linux-desktop-integration.service";

                optionalDesktop = lib.optional cfg.desktopIntegration desktopUnit;
              in
              {
                ancs4linux-advertising = mkAncsService "Advertising" {
                  execStart = bin "ancs4linux-advertising";
                  # Wait for both the D-Bus session bus *and* BlueZ.
                  after = [
                    "dbus.service"
                    "bluetooth.target"
                  ];
                  wants = [
                    "dbus.service"
                    setupUnit
                    observerUnit
                  ]
                  ++ optionalDesktop;
                  wantedBy = [ "default.target" ];
                };

                ancs4linux-setup = mkAncsService "BLE Advertising Setup" {
                  execStart = toString setupScript;
                  after = [ rootUnit ];
                  bindsTo = [ rootUnit ];
                  partOf = [ rootUnit ];
                  type = "oneshot";
                  extraServiceConfig = {
                    RemainAfterExit = true;
                    ExecStartPre = "${pkgs.coreutils}/bin/sleep ${toString cfg.setupDelay}";
                    # Don't let a stuck adapter hang the service manager
                    # for the default 90 s.
                    TimeoutStartSec = 30;
                  };
                };

                ancs4linux-observer = mkAncsService "Observer" {
                  execStart = bin "ancs4linux-observer";
                  after = [
                    rootUnit
                    setupUnit
                  ];
                  bindsTo = [ rootUnit ];
                  partOf = [ rootUnit ];
                };
              }
              // lib.optionalAttrs cfg.desktopIntegration {
                ancs4linux-desktop-integration = mkAncsService "Desktop Integration" {
                  execStart = bin "ancs4linux-desktop-integration";
                  after = [
                    observerUnit
                    setupUnit
                  ];
                  bindsTo = [ observerUnit ];
                  partOf = [ rootUnit ];
                };
              };
          };
        };
    };
}
