{ pkgs, ... }:

let
  # Spotify's Linux client never emits "now playing" notifications, so watch
  # its MPRIS interface and post one ourselves on each track change.
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
      last=""

      # trackid only changes per song, so play/pause toggles collapse into the
      # dedupe below and never re-notify.
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

            notify-send -a Spotify -i "$icon" \
              -h string:x-dunst-stack-tag:spotify-np \
              "$title" "$artist — $album"
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
