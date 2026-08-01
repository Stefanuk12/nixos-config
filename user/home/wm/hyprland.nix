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
      idfile="$cache/notify-id"         # shared with spotify-notify so both update one popup

      # noctalia honours the freedesktop replaces_id but has no stack-tag/x-canonical hint, so
      # replacement means remembering the id: -p prints the new one, -r reuses the last.
      notify() {
        local icon=spotify
        [ -f "$cover" ] && icon="$cover"
        local args=(-a Spotify -t 1500 -i "$icon" -p)
        local last new
        last=$(cat "$idfile" 2>/dev/null || echo 0)
        case "$last" in "" | *[!0-9]*) last=0 ;; esac
        [ "$last" -gt 0 ] && args+=(-r "$last")
        [ -n "''${3:-}" ] && args+=(-h "int:value:$3")
        if new=$(notify-send "''${args[@]}" "$1" "$2"); then
          printf '%s' "$new" > "$idfile"
        fi
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

  # Reads the descriptions off the bindd entries at runtime, so the cheatsheet cannot drift from
  # the actual binds. modmask is a bitfield, hence the decode.
  keybindsHint = pkgs.writeShellApplication {
    name = "keybinds-hint";
    runtimeInputs = with pkgs; [
      hyprland
      jq
      gawk
      less
      coreutils
    ];
    text = ''
      hyprctl binds -j \
        | jq -r '.[] | select(.description != "") | [.modmask, .key, .description] | @tsv' \
        | gawk -F'\t' '
            # Catppuccin Mocha, matching the noctalia theme.
            BEGIN {
              mauve    = "\033[38;2;203;166;247m"
              blue     = "\033[38;2;137;180;250m"
              text     = "\033[38;2;205;214;244m"
              subtext  = "\033[38;2;127;132;156m"
              overlay  = "\033[38;2;88;91;112m"
              bold     = "\033[1m"
              reset    = "\033[0m"
            }
            function mods(m,   s) {
              s = ""
              if (and(m, 64)) s = s "SUPER+"
              if (and(m,  4)) s = s "CTRL+"
              if (and(m,  8)) s = s "ALT+"
              if (and(m,  1)) s = s "SHIFT+"
              return s
            }
            function rank(g,   c) {
              if (g == "No modifier") return 900
              c = gsub(/\+/, "+", g)
              return (g ~ /^SUPER/ ? 0 : 100) + c
            }
            {
              combo = mods($1)
              group = combo
              sub(/\+$/, "", group)
              if (group == "") group = "No modifier"
              if (!(group in seen)) { seen[group] = 1; order[++groups] = group }
              n[group]++
              keys[group, n[group]]  = combo $2
              descs[group, n[group]] = $3
            }
            END {
              # SUPER-first, then fewest modifiers; bare keys (media/function) sink to the end.
              for (i = 1; i <= groups; i++)
                for (j = i + 1; j <= groups; j++) {
                  a = order[i]; b = order[j]
                  ra = rank(a); rb = rank(b)
                  if (rb < ra) { order[i] = b; order[j] = a }
                }

              printf "\n  %s%s╭─────────────────────────────────────────────╮%s\n", bold, mauve, reset
              printf "  %s%s│%s  %sKeybinds%s                                   %s%s│%s\n", bold, mauve, reset, bold text, reset, bold, mauve, reset
              printf "  %s%s╰─────────────────────────────────────────────╯%s\n", bold, mauve, reset

              for (i = 1; i <= groups; i++) {
                g = order[i]
                printf "\n  %s%s%s%s\n", bold, blue, g, reset
                printf "  %s────────────────────────────────────────────────%s\n", overlay, reset
                for (k = 1; k <= n[g]; k++)
                  printf "    %s%-24s%s %s%s%s\n", mauve, keys[g, k], reset, text, descs[g, k], reset
              }
              printf "\n  %s/ search   q or Esc to close%s\n\n", subtext, reset
            }
          ' \
        | less -R --no-init --quit-if-one-screen --tilde
    '';
  };
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
    # The share picker shells out to this for its Region tab, and xdph to it plus grim for
    # interactive screenshots; without it the picker just exits and the client re-prompts.
    slurp
    grim
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
        "[workspace special silent] spotify"
        "[workspace special silent] thunderbird"
        "systemctl --user start spotify-notify.service"
        "systemctl --user start osu-noctalia-dnd.service"
      ];

      windowrule = [
        "float on, match:title FreeRDP:.*"
        "stay_focused on, match:title FreeRDP:.*"
        "float on, match:title ^Keybinds$"
        "size 900 700, match:title ^Keybinds$"
        "center on, match:title ^Keybinds$"
        # vrr,2 on both monitors turns VRR on for whatever is fullscreen; this exempts LG,
        # which is fullscreen by default (win.fullScreen in looking_glass_client.nix).
        "no_vrr on, match:class ^looking-glass-client$"
      ];

      # bindd carries a description, which is what keybinds-hint reads back out.
      bindd = [
        # escape=close_surface is scoped to this window via the CLI rather than ghostty.nix, so
        # Esc keeps its normal meaning in every other terminal. "esc" is rejected as invalid.
        "$mainMod, slash, Show this keybind list, exec, $terminal --title=Keybinds --window-padding-x=18 --window-padding-y=14 --window-decoration=none --keybind=escape=close_surface -e ${keybindsHint}/bin/keybinds-hint"

        "$mainMod, Q, Close window, killactive"
        "ALT, F4, Close window, killactive"
        "$mainMod, W, Toggle floating, togglefloating"
        "$mainMod, G, Toggle group, togglegroup"
        "$mainMod, J, Toggle split direction, layoutmsg, togglesplit"
        "SHIFT, F11, Fullscreen, fullscreen"

        "$mainMod, T, Terminal, exec, $terminal"
        "$mainMod, E, File manager, exec, dolphin"
        "$mainMod, C, Editor, exec, codium"
        "$mainMod, B, Browser, exec, helium"
        "$mainMod, I, Bitwarden picker, exec, rofi-rbw"

        "$mainMod, Left, Focus left, movefocus, l"
        "$mainMod, Right, Focus right, movefocus, r"
        "$mainMod, Up, Focus up, movefocus, u"
        "$mainMod, Down, Focus down, movefocus, d"
        "ALT, Tab, Cycle windows, cyclenext"

        "$mainMod, S, Toggle scratchpad, togglespecialworkspace"
        "$mainMod SHIFT, S, Move to scratchpad, movetoworkspace, special"
        "$mainMod CONTROL, Right, Next workspace, workspace, r+1"
        "$mainMod CONTROL, Left, Previous workspace, workspace, r-1"
        "$mainMod CONTROL, Down, First empty workspace, workspace, empty"
        "$mainMod, mouse_down, Next workspace, workspace, e+1"
        "$mainMod, mouse_up, Previous workspace, workspace, e-1"

        # Noctalia owns the shell surfaces that HyDE gave to rofi/wlogout/hyprlock.
        "$mainMod, A, App launcher, exec, ${noctalia} msg panel-toggle launcher"
        "$mainMod, TAB, Window switcher, exec, ${noctalia} msg window-switcher"
        "$mainMod, V, Clipboard history, exec, ${noctalia} msg panel-toggle clipboard"
        "$mainMod, N, Control centre, exec, ${noctalia} msg panel-toggle control-center"
        "$mainMod, L, Lock screen, exec, ${noctalia} msg session lock"
        "CONTROL ALT, Delete, Session menu, exec, ${noctalia} msg panel-toggle session"
        "$mainMod SHIFT, W, Wallpaper picker, exec, ${noctalia} msg panel-toggle wallpaper"
        "$mainMod ALT, Right, Next wallpaper, exec, ${noctalia} msg wallpaper-next"
        "$mainMod ALT, Left, Previous wallpaper, exec, ${noctalia} msg wallpaper-previous"
        "$mainMod, P, Screenshot region, exec, ${noctalia} msg screenshot-region"
        "$mainMod ALT, P, Screenshot all monitors, exec, ${noctalia} msg screenshot-fullscreen"
        ", Print, Screenshot all monitors, exec, ${noctalia} msg screenshot-fullscreen"
        "$mainMod SHIFT, P, Colour picker, exec, hyprpicker -an"
      ]
      ++ builtins.concatMap (
        n:
        let
          ws = if n == "0" then "10" else n;
        in
        [
          "$mainMod, ${n}, Go to workspace ${ws}, workspace, ${ws}"
          "$mainMod SHIFT, ${n}, Move window to workspace ${ws}, movetoworkspace, ${ws}"
          "$mainMod ALT, ${n}, Move window to workspace ${ws} silently, movetoworkspacesilent, ${ws}"
        ]
      ) [ "1" "2" "3" "4" "5" "6" "7" "8" "9" "0" ];

      binddm = [
        "$mainMod, mouse:272, Drag to move window, movewindow"
        "$mainMod, mouse:273, Drag to resize window, resizewindow"
        "$mainMod, Z, Hold to move window, movewindow"
        "$mainMod, X, Hold to resize window, resizewindow"
      ];

      bindde = [
        "$mainMod SHIFT, Right, Grow window right, resizeactive, 30 0"
        "$mainMod SHIFT, Left, Shrink window left, resizeactive, -30 0"
        "$mainMod SHIFT, Up, Shrink window up, resizeactive, 0 -30"
        "$mainMod SHIFT, Down, Grow window down, resizeactive, 0 30"
      ];

      # Bare -> Spotify's own MPRIS volume/transport, SUPER -> the system sink via noctalia.
      binddl = [
        ", XF86AudioPlay, Spotify play / pause, exec, ${spotifyOsd}/bin/spotify-osd playpause"
        ", XF86AudioPause, Spotify play / pause, exec, ${spotifyOsd}/bin/spotify-osd playpause"
        ", XF86AudioNext, Spotify next track, exec, playerctl -p spotify,%any next"
        ", XF86AudioPrev, Spotify previous track, exec, playerctl -p spotify,%any previous"
        ", XF86AudioMute, Mute Spotify only, exec, ${spotifyOsd}/bin/spotify-osd mute"
        "SUPER, XF86AudioPlay, Play / pause any player, exec, playerctl play-pause"
        "SUPER, XF86AudioPause, Play / pause any player, exec, playerctl play-pause"
        "SUPER, XF86AudioNext, Next track any player, exec, playerctl next"
        "SUPER, XF86AudioPrev, Previous track any player, exec, playerctl previous"
        "SUPER, XF86AudioMute, Mute system output, exec, ${noctalia} msg volume-mute"
        ", XF86AudioMicMute, Mute microphone, exec, ${noctalia} msg mic-mute"
      ];

      binddel = [
        ", XF86AudioRaiseVolume, Spotify volume up, exec, ${spotifyOsd}/bin/spotify-osd up"
        ", XF86AudioLowerVolume, Spotify volume down, exec, ${spotifyOsd}/bin/spotify-osd down"
        "SUPER, XF86AudioRaiseVolume, System volume up, exec, ${noctalia} msg volume-up"
        "SUPER, XF86AudioLowerVolume, System volume down, exec, ${noctalia} msg volume-down"
        # noctalia's brightness-set is absolute and rejects negatives, so step with brightnessctl
        # and let noctalia's brightness OSD pick the change up.
        ", XF86MonBrightnessUp, Brightness up, exec, brightnessctl set 5%+"
        ", XF86MonBrightnessDown, Brightness down, exec, brightnessctl set 5%-"
      ];
    };
  };

  # Discord tears its screencast session down and opens a new one every second or so; without a
  # restore token each of those is another share picker. This pre-ticks the picker's "allow
  # restoring" box, so the second session onwards restores silently instead of prompting.
  xdg.configFile."hypr/xdph.conf".text = ''
    screencopy {
      allow_token_by_default = true
    }
  '';
}
