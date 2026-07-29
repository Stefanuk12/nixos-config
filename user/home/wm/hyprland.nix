{ config, pkgs, lib, ... }:

let
  # playerctl and the Spotify client give no on-screen feedback for the media keys; the SUPER
  # (system) bindings go through noctalia's own OSD instead.
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

      # noctalia coalesces by app name, so a single Spotify popup updates in place.
      notify() {
        local icon=spotify
        [ -f "$cover" ] && icon="$cover"
        local args=(-a Spotify -t 1500 -i "$icon")
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

  # Belt-and-braces from the HyDE days, when graphical-session.target never activated and the
  # portal only D-Bus-activated on first use. uwsm reaches the target, so this is just a guard.
  heliumDeferred = pkgs.writeShellApplication {
    name = "helium-deferred";
    runtimeInputs = with pkgs; [ glib helium systemd ];
    text = ''
      systemctl --user start xdg-desktop-portal.service || true
      gdbus wait --session --timeout 30 org.freedesktop.portal.Desktop || true
      exec helium "$@"
    '';
  };

  terminal = config.userSettings.terminal;
  noctalia = "${config.programs.noctalia.package}/bin/noctalia";
in
{
  home.packages = with pkgs; [
    networkmanagerapplet
    playerctl
    brightnessctl
    pavucontrol
    wl-clipboard
    hyprpicker
    hyprsunset
    libnotify
  ];

  xdg.userDirs.setSessionVariables = true;

  wayland.windowManager.hyprland = {
    enable = true;
    systemd.enable = false; # uwsm owns the session
    # Pinned: settings below are hyprlang, and this silently flips to "lua" at stateVersion 26.05.
    configType = "hyprlang";

    settings = {
      "$mainMod" = "SUPER";
      "$terminal" = terminal;

      monitor = [
        # G24F is anchored at 0,0 so nothing (cursor spawn, notifications, layer-shell bars) is
        # stranded there when the Acer is unplugged. Acer sits to its left; use 1920x0 if it moves.
        "desc:GIGA-BYTE TECHNOLOGY CO. LTD. GIGABYTE G24F, 1920x1080@165, 0x0, 1, vrr, 2, bitdepth, 10"
        "desc:Acer Technologies VG240Y, 1920x1080@75, -1920x0, 1, vrr, 2"
      ];

      workspace = [
        "1, monitor:desc:GIGA-BYTE TECHNOLOGY CO. LTD. GIGABYTE G24F, default:true"
        "2, monitor:desc:Acer Technologies VG240Y, default:true"
      ];

      env = [
        "AQ_DRM_DEVICES,/dev/dri/amd-igpu"
        # Lets the iGPU compositor import frames rendered on the dGPU (else games offloaded to the
        # 5080 are a black screen).
        "AQ_NO_MODIFIERS,1"
        "AQ_MGPU_NO_EXPLICIT,1"
      ];

      input = {
        kb_layout = "iso_us";
        accel_profile = "flat";
        # 0, not the -0.8 the HyDE config asked for: HyDE failed to source userprefs.conf, so
        # -0.8 was never actually applied and 0 is what the mouse really felt like.
        sensitivity = 0;
        # Hands games unaccelerated deltas instead of the compositor's processed motion. flat at
        # speed 0 happens to be equivalent today, so this is about not depending on that.
        force_no_accel = true;
        follow_mouse = 1;
      };

      # DP-1 is the G24F. Places the cursor there at login, so it is the monitor that starts
      # focused; the Acer is HDMI-A-1 and enumerates first, which would otherwise win.
      cursor.default_monitor = "DP-1";

      general = {
        gaps_in = 4;
        gaps_out = 8;
        border_size = 2;
        layout = "dwindle";
      };

      decoration = {
        rounding = 10;
        blur.enabled = true;
      };

      misc = {
        disable_hyprland_logo = true;
        disable_splash_rendering = true;
      };

      # XWayland games that set the cursor every frame spam "cursorImage request", and Hyprland
      # logs on its main thread — 100MB+ logs and in-game hitches. Re-enable only to debug.
      "debug:disable_logs" = true;

      exec-once = [
        "kdeconnect-indicator"
        "[workspace 2 silent] ${heliumDeferred}/bin/helium-deferred"
        "systemctl --user start spotify-notify.service"
        "systemctl --user start osu-noctalia-dnd.service"
      ];

      windowrule = [
        "float on, match:title FreeRDP:.*"
        "stay_focused on, match:title FreeRDP:.*"
      ];

      bind = [
        "$mainMod, Q, killactive"
        "ALT, F4, killactive"
        "$mainMod, W, togglefloating"
        "$mainMod, G, togglegroup"
        "$mainMod, J, layoutmsg, togglesplit"
        "SHIFT, F11, fullscreen"

        "$mainMod, T, exec, $terminal"
        "$mainMod, E, exec, dolphin"
        "$mainMod, C, exec, codium"
        "$mainMod, B, exec, helium"

        "$mainMod, Left, movefocus, l"
        "$mainMod, Right, movefocus, r"
        "$mainMod, Up, movefocus, u"
        "$mainMod, Down, movefocus, d"
        "ALT, Tab, cyclenext"

        "$mainMod, S, togglespecialworkspace"
        "$mainMod SHIFT, S, movetoworkspace, special"
        "$mainMod CONTROL, Right, workspace, r+1"
        "$mainMod CONTROL, Left, workspace, r-1"
        "$mainMod CONTROL, Down, workspace, empty"
        "$mainMod, mouse_down, workspace, e+1"
        "$mainMod, mouse_up, workspace, e-1"

        # Noctalia owns the shell surfaces that HyDE gave to rofi/wlogout/hyprlock.
        "$mainMod, A, exec, ${noctalia} msg panel-toggle launcher"
        "$mainMod, TAB, exec, ${noctalia} msg window-switcher"
        "$mainMod, V, exec, ${noctalia} msg panel-toggle clipboard"
        "$mainMod, N, exec, ${noctalia} msg panel-toggle control-center"
        "$mainMod, L, exec, ${noctalia} msg session lock"
        "CONTROL ALT, Delete, exec, ${noctalia} msg panel-toggle session"
        "$mainMod SHIFT, W, exec, ${noctalia} msg panel-toggle wallpaper"
        "$mainMod ALT, Right, exec, ${noctalia} msg wallpaper-next"
        "$mainMod ALT, Left, exec, ${noctalia} msg wallpaper-previous"
        "$mainMod, P, exec, ${noctalia} msg screenshot-region"
        "$mainMod ALT, P, exec, ${noctalia} msg screenshot-fullscreen"
        ", Print, exec, ${noctalia} msg screenshot-fullscreen"
        "$mainMod SHIFT, P, exec, hyprpicker -an"

        "$mainMod, I, exec, rofi-rbw"
      ]
      ++ builtins.concatMap (n: [
        "$mainMod, ${n}, workspace, ${if n == "0" then "10" else n}"
        "$mainMod SHIFT, ${n}, movetoworkspace, ${if n == "0" then "10" else n}"
        "$mainMod ALT, ${n}, movetoworkspacesilent, ${if n == "0" then "10" else n}"
      ]) [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "0" ];

      bindm = [
        "$mainMod, mouse:272, movewindow"
        "$mainMod, mouse:273, resizewindow"
        "$mainMod, Z, movewindow"
        "$mainMod, X, resizewindow"
      ];

      binde = [
        "$mainMod SHIFT, Right, resizeactive, 30 0"
        "$mainMod SHIFT, Left, resizeactive, -30 0"
        "$mainMod SHIFT, Up, resizeactive, 0 -30"
        "$mainMod SHIFT, Down, resizeactive, 0 30"
      ];

      # Bare -> Spotify's own MPRIS volume/transport, SUPER -> the system sink via noctalia.
      bindl = [
        ", XF86AudioPlay, exec, ${spotifyOsd}/bin/spotify-osd playpause"
        ", XF86AudioPause, exec, ${spotifyOsd}/bin/spotify-osd playpause"
        ", XF86AudioNext, exec, playerctl -p spotify,%any next"
        ", XF86AudioPrev, exec, playerctl -p spotify,%any previous"
        ", XF86AudioMute, exec, ${spotifyOsd}/bin/spotify-osd mute"
        "SUPER, XF86AudioPlay, exec, playerctl play-pause"
        "SUPER, XF86AudioPause, exec, playerctl play-pause"
        "SUPER, XF86AudioNext, exec, playerctl next"
        "SUPER, XF86AudioPrev, exec, playerctl previous"
        "SUPER, XF86AudioMute, exec, ${noctalia} msg volume-mute"
        ", XF86AudioMicMute, exec, ${noctalia} msg mic-mute"
      ];

      bindel = [
        ", XF86AudioRaiseVolume, exec, ${spotifyOsd}/bin/spotify-osd up"
        ", XF86AudioLowerVolume, exec, ${spotifyOsd}/bin/spotify-osd down"
        "SUPER, XF86AudioRaiseVolume, exec, ${noctalia} msg volume-up"
        "SUPER, XF86AudioLowerVolume, exec, ${noctalia} msg volume-down"
        # noctalia's brightness-set is absolute and rejects negatives, so step with brightnessctl
        # and let noctalia's brightness OSD pick the change up.
        ", XF86MonBrightnessUp, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, exec, brightnessctl set 5%-"
      ];
    };
  };
}
