{ inputs, pkgs, ... }:

let
  # On-screen feedback for Spotify media keys -- playerctl itself is silent and
  # the desktop client never notifies. Subcommands: up/down (volume + progress
  # bar), mute (toggle, emulated via MPRIS volume since Spotify has no mute),
  # playpause (shows the resulting Playing/Paused state). The SUPER/system paths
  # keep HyDE's own OSD via hyde-shell volumecontrol.
  spotifyOsd = pkgs.writeShellApplication {
    name = "spotify-osd";
    runtimeInputs = with pkgs; [
      playerctl
      libnotify
      gawk
      coreutils
    ];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/spotify-notify"
      mkdir -p "$cache"
      cover="$cache/cover.jpg"          # cached by the spotify-notify service
      statefile="$cache/premute-vol"

      # All Spotify OSDs share one dunst stack-tag, so there is only ever a
      # single Spotify popup that updates in place.
      notify() {
        local icon=spotify
        [ -f "$cover" ] && icon="$cover"
        local args=(-a Spotify -t 1500 -i "$icon" -h string:x-dunst-stack-tag:spotify-np)
        [ -n "''${3:-}" ] && args+=(-h "int:value:$3")
        notify-send "''${args[@]}" "$1" "$2"
      }

      vol_pct() {
        local v
        v=$(playerctl -p spotify volume 2>/dev/null) || { echo 0; return; }
        awk -v v="$v" 'BEGIN { p = v*100; if (p<0) p=0; if (p>100) p=100; printf "%d", p+0.5 }'
      }

      # seconds -> M:SS
      fmt() {
        awk -v s="$1" 'BEGIN { s = int(s+0.5); if (s<0) s=0; printf "%d:%02d", int(s/60), s%60 }'
      }

      title=$(playerctl -p spotify,%any metadata title 2>/dev/null) || true
      artist=$(playerctl -p spotify,%any metadata artist 2>/dev/null) || true

      case "''${1:-}" in
        up | down)
          if [ "$1" = up ]; then
            playerctl -p spotify volume 0.05+
          else
            playerctl -p spotify volume 0.05-
          fi
          pct=$(vol_pct)
          notify "$title — $artist" "Volume $pct%" "$pct"
          ;;
        mute)
          vol=$(playerctl -p spotify volume 2>/dev/null) || exit 0
          if awk -v v="$vol" 'BEGIN { exit !(v > 0) }'; then
            printf '%s' "$vol" > "$statefile"   # remember level to restore
            playerctl -p spotify volume 0
            notify "$title — $artist" "Muted" 0
          else
            restore=$(cat "$statefile" 2>/dev/null || echo 0.5)
            playerctl -p spotify volume "$restore"
            pct=$(vol_pct)
            notify "$title — $artist" "Volume $pct%" "$pct"
          fi
          ;;
        playpause)
          if [ "$(playerctl -p spotify,%any status 2>/dev/null)" = Playing ]; then
            playerctl -p spotify,%any pause
            state=Paused
          else
            playerctl -p spotify,%any play
            state=Playing
          fi
          pos=$(playerctl -p spotify,%any position 2>/dev/null) || pos=0
          len=$(playerctl -p spotify,%any metadata mpris:length 2>/dev/null) || len=0
          len_s=$(awk -v l="$len" 'BEGIN { printf "%.3f", l/1000000 }')
          prog=$(awk -v p="$pos" -v l="$len" 'BEGIN { l=l/1000000; if (l<=0) { print 0; exit } r=p/l*100; if (r<0) r=0; if (r>100) r=100; printf "%d", r+0.5 }')
          notify "$title — $artist" "$state · $(fmt "$pos") / $(fmt "$len_s")" "$prog"
          ;;
      esac
    '';
  };
in
{
  imports = [
    inputs.hydenix.homeModules.default
  ];

  # need this because `network` was disabled
  home.packages = with pkgs; [
    networkmanagerapplet
  ];

  xdg.userDirs.setSessionVariables = true;

  hydenix.hm = {
    enable = true;

    editors.neovim = false;
    editors.vscode.enable = false;
    editors.vim = false;
    editors.default = "codium";

    firefox.enable = false;
    git.enable = false;
    social.enable = false;
  };

  hydenix.hm.hyprland = {
    enable = true;
    suppressWarnings = true;
    extraConfig = ''
      exec-once = kdeconnect-indicator
      exec-once = [workspace 2 silent] brave
      env = AQ_DRM_DEVICES,/dev/dri/amd-igpu

      workspace = 1, monitor:desc:GIGA-BYTE TECHNOLOGY CO. LTD. GIGABYTE G24F, default:true
      workspace = 2, monitor:desc:Acer Technologies VG240Y, default:true

      input {
        kb_layout = iso_us
        accel_profile = "flat"
        sensitivity = -0.8
      }

      windowrule = float on, match:title FreeRDP:.*
      windowrule = stay_focused on, match:title FreeRDP:.*
    '';
    keybindings.extraConfig = ''
      bind = SUPER, I, exec, rofi-rbw

      # Media keys: bare -> Spotify, SUPER -> the generic "system" player.
      # (HyDE's defaults bind bare `playerctl`, which grabs whatever MPRIS
      # player is active -- usually a Brave/YouTube tab. Flip it: Spotify is
      # the default, the active/other player moves under SUPER.)
      unbind = , XF86AudioPlay
      unbind = , XF86AudioPause
      unbind = , XF86AudioNext
      unbind = , XF86AudioPrev
      bindl = , XF86AudioPlay, exec, ${spotifyOsd}/bin/spotify-osd playpause
      bindl = , XF86AudioPause, exec, ${spotifyOsd}/bin/spotify-osd playpause
      bindl = , XF86AudioNext, exec, playerctl -p spotify,%any next
      bindl = , XF86AudioPrev, exec, playerctl -p spotify,%any previous
      bindl = SUPER, XF86AudioPlay, exec, playerctl play-pause
      bindl = SUPER, XF86AudioPause, exec, playerctl play-pause
      bindl = SUPER, XF86AudioNext, exec, playerctl next
      bindl = SUPER, XF86AudioPrev, exec, playerctl previous

      # Volume: bare knob -> Spotify's MPRIS volume, SUPER -> system sink.
      unbind = , XF86AudioRaiseVolume
      unbind = , XF86AudioLowerVolume
      bindel = , XF86AudioRaiseVolume, exec, ${spotifyOsd}/bin/spotify-osd up
      bindel = , XF86AudioLowerVolume, exec, ${spotifyOsd}/bin/spotify-osd down
      bindel = SUPER, XF86AudioRaiseVolume, exec, hyde-shell volumecontrol -o i
      bindel = SUPER, XF86AudioLowerVolume, exec, hyde-shell volumecontrol -o d

      # Mute: bare -> mute Spotify only, SUPER -> system sink.
      unbind = , XF86AudioMute
      bindl = , XF86AudioMute, exec, ${spotifyOsd}/bin/spotify-osd mute
      bindl = SUPER, XF86AudioMute, exec, hyde-shell volumecontrol -o m
    '';
    monitors.overrideConfig = ''
      monitor = desc:Acer Technologies VG240Y, 1920x1080@75, 0x0, 1, vrr, 2
      monitor = desc:GIGA-BYTE TECHNOLOGY CO. LTD. GIGABYTE G24F, 1920x1080@165, 1920x0, 1, vrr, 2, bitdepth, 10
      monitor = , disable
    '';
  };
}
