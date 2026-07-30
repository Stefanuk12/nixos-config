{ pkgs, ... }:

let
  # Spotify's Linux client emits no "now playing" notification, so watch MPRIS and post one.
  spotifyNotify = pkgs.writeShellApplication {
    name = "spotify-notify";
    runtimeInputs = with pkgs; [
      playerctl
      libnotify
      curl
      coreutils
    ];
    text = ''
      cache="''${XDG_CACHE_HOME:-$HOME/.cache}/spotify-notify"
      mkdir -p "$cache"
      cover="$cache/cover.jpg"
      idfile="$cache/notify-id"   # shared with spotify-osd so both replace the same popup
      last=""

      # trackid only changes per song, so play/pause toggles collapse into the dedupe below.
      playerctl -p spotify --follow metadata --format '{{mpris:trackid}}' 2>/dev/null \
        | while read -r trackid; do
            [ -z "$trackid" ] && continue
            [ "$trackid" = "$last" ] && continue
            last="$trackid"

            [ "$(playerctl -p spotify status 2>/dev/null)" = "Playing" ] || continue

            title=$(playerctl -p spotify metadata title 2>/dev/null) || true
            artist=$(playerctl -p spotify metadata artist 2>/dev/null) || true
            album=$(playerctl -p spotify metadata album 2>/dev/null) || true
            url=$(playerctl -p spotify metadata mpris:artUrl 2>/dev/null) || true

            icon=spotify
            if [ -n "$url" ] && curl -sfL --max-time 5 "$url" -o "$cover"; then
              icon="$cover"
            fi

            # noctalia has no stack-tag hint, so replacement rides on the freedesktop
            # replaces_id: -p prints the new id, -r reuses the previous one.
            prev=$(cat "$idfile" 2>/dev/null || echo 0)
            case "$prev" in "" | *[!0-9]*) prev=0 ;; esac
            args=(-a Spotify -i "$icon" -p)
            [ "$prev" -gt 0 ] && args+=(-r "$prev")
            if nid=$(notify-send "''${args[@]}" "$title" "$artist — $album"); then
              printf '%s' "$nid" > "$idfile"
            fi
          done
    '';
  };
in
{
  home.packages = [ spotifyNotify ];

  systemd.user.services.spotify-notify = {
    Unit = {
      Description = "Desktop notification for the currently playing Spotify track";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${spotifyNotify}/bin/spotify-notify";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
