{ inputs, pkgs, ... }:

let
  # Pause dunst on workspaces with an osu! window so notifications can't trigger compositor repaint stalls mid-gameplay; they queue and pop after we leave.
  osuDunstSuppress = pkgs.writeShellApplication {
    name = "osu-dunst-suppress";
    runtimeInputs = with pkgs; [
      hyprland
      socat
      jq
      dunst
    ];
    text = ''
      set -uo pipefail

      socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

      paused=""

      apply() {
        if [ "$1" != "$paused" ]; then
          dunstctl set-paused "$1" >/dev/null 2>&1 || return 0
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
    pkgs.osu-lazer-bin
    inputs.osu-collect.packages.${pkgs.stdenv.hostPlatform.system}.default
    osuDunstSuppress
  ];

  systemd.user.services.osu-dunst-suppress = {
    Unit = {
      Description = "Pause dunst on workspaces containing an osu! window";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${osuDunstSuppress}/bin/osu-dunst-suppress";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
