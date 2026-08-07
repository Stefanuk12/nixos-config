{ config, lib, pkgs, ... }:

let
  cfg = config.services.sunshineGreeter;
  greeter = config.programs.noctalia-greeter;
  stateDir = "/var/lib/sunshine-greeter";

  # Sunshine derives a whole block from this (base-5, base, base+1, base+21 TCP; base+9..+21 UDP),
  # so it has to clear the user session's 47984-48010 — both instances exist for a moment during
  # the handover from greeter to session.
  basePort = 47929;

  configFile = (pkgs.formats.keyValue { }).generate "sunshine-greeter.conf" {
    sunshine_name = "home (login screen)";
    port = basePort;
    # The greeter's own compositor implements no wlr-screencopy, so the Wayland path Sunshine picks
    # by default has nothing to attach to. KMS reads the scanout framebuffer instead and needs no
    # cooperation from the compositor — which is what services.sunshine.capSysAdmin is for.
    capture = "kms";
    file_state = "${stateDir}/state.json";
    credentials_file = "${stateDir}/credentials.json";
    log_path = "${stateDir}/sunshine.log";
  };

  session = pkgs.writeShellApplication {
    name = "greeter-session-with-sunshine";
    runtimeInputs = [ pkgs.coreutils ];
    text = ''
      ${greeter.package}/bin/noctalia-greeter-session -- ${greeter.greeter-args} &
      greeter_pid=$!
      sunshine_pid=""

      stop_sunshine() {
        if [ -n "$sunshine_pid" ]; then
          kill "$sunshine_pid" 2>/dev/null || true
        fi
      }
      # greetd kills this wrapper on login; without this Sunshine outlives it, holds the state file
      # open and keeps its ports bound against the next greeter.
      trap stop_sunshine EXIT TERM INT

      # noctalia-greeter-session pins XDG_RUNTIME_DIR to this, and its compositor takes wayland-0.
      runtime="/tmp/noctalia-runtime-$(id -u)"
      for _ in $(seq 1 100); do
        if [ -S "$runtime/wayland-0" ]; then
          HOME="${stateDir}" XDG_RUNTIME_DIR="$runtime" WAYLAND_DISPLAY=wayland-0 \
            ${config.security.wrapperDir}/sunshine ${configFile} &
          sunshine_pid=$!
          break
        fi
        sleep 0.2
      done

      wait "$greeter_pid"
    '';
  };
in
{
  options.services.sunshineGreeter.enable = lib.mkEnableOption ''
    Sunshine inside the greetd session, so the login screen itself can be streamed and a machine
    woken by Wake-on-LAN can be logged into remotely.

    Off by default because it listens before anyone has authenticated: a network-reachable service
    that can inject input into the login screen, running from boot. Only worth it if you need
    remote access after a cold boot rather than after a suspend
  '';

  config = lib.mkIf cfg.enable {
    services.greetd.settings.default_session.command = lib.getExe session;

    # uinput to inject input, video/render for the DRM nodes KMS capture and VAAPI encoding need.
    users.users.greeter.extraGroups = [ "uinput" "video" "render" ];

    # Pairing and the web-UI password live here, separate from the user session's Sunshine, so a
    # compromise of the login-screen instance does not carry over. Survives disabling this module,
    # so re-enabling does not mean pairing again.
    systemd.tmpfiles.settings."10-sunshine-greeter".${stateDir}.d = {
      user = "greeter";
      group = "greeter";
      mode = "0700";
    };
  };
}
