{ pkgs, ... }:

let
  gap = 16;
  tileW = 480;
  tileH = 270;
  # Active and inactive alike: the tiles are never focused, so a single value would leave them
  # opaque in practice.
  opacity = "0.75 0.75";
  stash = "special:camstash";

  # Every Vesktop popout ("Pop Out" on a call tile) is created as a BrowserWindow titled
  # "Discord Popout" before the page renames it to the speaker's name, so initial_title is what
  # identifies one; the main window starts as "Discord".
  match = "match:class ^vesktop$, match:initial_title ^Discord Popout$";

  overlay = pkgs.writeShellScript "discord-camera-overlay" ''
    set -euo pipefail

    # toggle: the keybind, flips arranged <-> stashed.
    # arrange: the watcher, follows whichever state the overlay is already in so that a popout
    #          opening while the tiles are hidden does not yank them all back on screen.
    # stash:   hide unconditionally.
    mode=''${1:-toggle}

    clients=$(hyprctl clients -j)
    # Anything Vesktop opens that is not the main window is a popout. Broader than the rules
    # below on purpose: should Discord ever title a popout something else, the rules miss it but
    # this still finds it, and the loop re-applies the one that matters.
    filter='.[] | select(.class == "vesktop" and .initialTitle != "Discord")'

    mapfile -t popouts < <(${pkgs.jq}/bin/jq -r "$filter | .address" <<<"$clients")

    if [ ''${#popouts[@]} -eq 0 ]; then
      if [ "$mode" = toggle ]; then
        ${pkgs.libnotify}/bin/notify-send -a "Camera overlay" "No camera popouts open" \
          "Join a call with cameras on, or pop a tile out by hand."
      fi
      exit 0
    fi

    pinned=$(${pkgs.jq}/bin/jq "[$filter | select(.pinned)] | length" <<<"$clients")
    hidden=$(${pkgs.jq}/bin/jq "[$filter | select(.workspace.name == \"${stash}\")] | length" <<<"$clients")

    case "$mode" in
      stash) hide=1 ;;
      toggle) [ "$pinned" -gt 0 ] && hide=1 || hide=0 ;;
      *) [ "$hidden" -gt 0 ] && hide=1 || hide=0 ;;
    esac

    # pin is a toggle, so both branches ask first: pinning an already-pinned window unpins it,
    # and a window left pinned ignores movetoworkspacesilent and stays on screen.
    is_pinned() {
      [ "$(${pkgs.jq}/bin/jq -r --arg a "$1" 'first(.[] | select(.address == $a)).pinned' <<<"$clients")" = true ]
    }

    if [ "$hide" = 1 ]; then
      for a in "''${popouts[@]}"; do
        unpin=""
        if is_pinned "$a"; then unpin="; dispatch pin address:$a"; fi
        hyprctl --batch "dispatch setprop address:$a no_screen_share true $unpin \
          ; dispatch movetoworkspacesilent ${stash},address:$a" >/dev/null
      done
      exit 0
    fi

    mon=$(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r 'first(.[] | select(.focused)) | .id')

    # reserved is [left, top, right, bottom] — keeps a corner tile out from under the bar when the
    # game is not actually fullscreen.
    read -r mx my mw mh ws < <(hyprctl monitors -j | ${pkgs.jq}/bin/jq -r --argjson id "$mon" '
      first(.[] | select(.id == $id))
      | "\(.x + .reserved[0]) \(.y + .reserved[1])"
      + " \((.width / .scale | floor) - .reserved[0] - .reserved[2])"
      + " \((.height / .scale | floor) - .reserved[1] - .reserved[3]) \(.activeWorkspace.id)"')

    n=''${#popouts[@]}
    if [ "$n" -le 4 ]; then
      w=${toString tileW}
      h=${toString tileH}
    else
      # Past four corners the tiles become a column down the right edge, shrunk to fit.
      h=$(( (mh - ${toString gap} * (n + 1)) / n ))
      w=$(( h * 16 / 9 ))
    fi

    i=0
    for a in "''${popouts[@]}"; do
      if [ "$n" -le 4 ]; then
        case $i in
          0) x=$(( mx + mw - ${toString gap} - w )); y=$(( my + ${toString gap} )) ;;
          1) x=$(( mx + mw - ${toString gap} - w )); y=$(( my + mh - ${toString gap} - h )) ;;
          2) x=$(( mx + ${toString gap} ));         y=$(( my + mh - ${toString gap} - h )) ;;
          *) x=$(( mx + ${toString gap} ));         y=$(( my + ${toString gap} )) ;;
        esac
      else
        x=$(( mx + mw - ${toString gap} - w ))
        y=$(( my + ${toString gap} + i * (h + ${toString gap}) ))
      fi

      pin=""
      if ! is_pinned "$a"; then pin="; dispatch pin address:$a"; fi

      hyprctl --batch "dispatch movetoworkspacesilent $ws,address:$a \
        ; dispatch setprop address:$a no_screen_share true \
        ; dispatch setfloating address:$a \
        ; dispatch resizewindowpixel exact $w $h,address:$a \
        ; dispatch movewindowpixel exact $x $y,address:$a $pin" >/dev/null
      i=$(( i + 1 ))
    done
  '';

  # The plugin opens the popouts in a burst, so react to Hyprland's own window events rather than
  # making the user press the keybind once everyone's camera is up.
  watcher = pkgs.writeShellScript "discord-camera-overlay-watch" ''
    set -uo pipefail
    sock="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

    pending=""
    ${pkgs.socat}/bin/socat -U - "UNIX-CONNECT:$sock" | while read -r line; do
      case "$line" in
        openwindow\>\>*vesktop,*|closewindow\>\>*) ;;
        *) continue ;;
      esac

      [ -n "$pending" ] && kill "$pending" 2>/dev/null
      ( sleep 0.7; ${overlay} arrange ) &
      pending=$!
    done
  '';
in
{
  wayland.windowManager.hyprland.settings = {
    windowrule = [
      "float on, ${match}"
      "size ${toString tileW} ${toString tileH}, ${match}"
      "keep_aspect_ratio on, ${match}"
      "opacity ${opacity}, ${match}"
      # A camera popping out mid-round must not take the keyboard off the game.
      "no_initial_focus on, ${match}"
      # Keeps the tiles out of the Discord screenshare so nobody watches their own face come back
      # at them. Sunshine reads the scanout framebuffer (KMS), which this does not touch, so the
      # Apple TV cast still shows them. The script sets the same prop on every window it arranges,
      # so a popout this rule fails to match still cannot leak into the share.
      "no_screen_share on, ${match}"
      # Pinning is left to the script: it reads pinned state to decide stash vs. arrange, and a
      # rule that pinned on map would invert that.
    ];

    bindd = [ "SUPER ALT, D, Toggle Discord camera overlay, exec, ${overlay}" ];
  };

  systemd.user.services.discord-camera-overlay = {
    Unit = {
      Description = "Arrange Discord camera popouts into the screen corners as they open";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${watcher}";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
