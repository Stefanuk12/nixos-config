{ config, inputs, pkgs, ... }:

let
  gpuEnv = import ../../../../hosts/home/gpu-env.nix;

  noctalia = "${config.programs.noctalia.package}/bin/noctalia";

  # Notifications trigger compositor repaint stalls mid-gameplay; they queue and pop on leaving.
  osuDndSuppress = pkgs.writeShellApplication {
    name = "osu-noctalia-dnd";
    runtimeInputs = with pkgs; [
      hyprland
      socat
      jq
    ];
    text = ''
      set -uo pipefail

      socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

      paused=""

      apply() {
        if [ "$1" != "$paused" ]; then
          ${noctalia} msg notification-dnd-set "$1" >/dev/null 2>&1 || return 0
          paused="$1"
        fi
      }

      check() {
        local ws
        ws=$(hyprctl activeworkspace -j | jq -r '.id')
        local osu_count
        osu_count=$(
          hyprctl clients -j \
            | jq -r --argjson ws "$ws" \
                '[.[] | select(.workspace.id == $ws and (.class // "" | test("osu!"; "i")))] | length'
        )
        if [ "$osu_count" -gt 0 ]; then
          apply true
        else
          apply false
        fi
      }

      check
      socat -u "UNIX-CONNECT:$socket" - | while read -r line; do
        case "$line" in
          workspace\>\>*|focusedmon\>\>*|openwindow\>\>*|closewindow\>\>*|movewindow\>\>*)
            check
            ;;
        esac
      done
    '';
  };
in
{
  home.packages = [
    (gpuEnv.onDgpu pkgs pkgs.osu-lazer-bin)
    inputs.osu-collect.packages.${pkgs.stdenv.hostPlatform.system}.default
    osuDndSuppress
  ];

  systemd.user.services.osu-noctalia-dnd = {
    Unit = {
      Description = "Enable noctalia DND on workspaces containing an osu! window";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${osuDndSuppress}/bin/osu-noctalia-dnd";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
