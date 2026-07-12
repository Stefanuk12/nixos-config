{ pkgs, ... }:

let
  # Thin yt-dlp wrapper: gives each download a clean, per-site filename and
  # auto-sorts it into ~/Videos or ~/Music. Any extra flags are forwarded
  # straight to yt-dlp, e.g.
  #   getmedia https://youtu.be/xyz                       # video  -> ~/Videos
  #   getmedia -t mp3 https://youtu.be/xyz                # audio  -> ~/Music
  #   getmedia --cookies-from-browser firefox <ig-url>    # private Instagram
  #   getmedia --yes-playlist <playlist-url>              # whole playlist
  getmedia = pkgs.writeShellApplication {
    name = "getmedia";
    runtimeInputs = with pkgs; [
      yt-dlp
      ffmpeg # muxing, audio extraction
      atomicparsley # thumbnail embedding for mp4/m4a
      coreutils
    ];
    text = ''
      if [ "$#" -eq 0 ]; then
        echo "usage: getmedia [yt-dlp options] <url> [url...]" >&2
        echo "  audio only: getmedia -t mp3 <url>" >&2
        exit 1
      fi

      video_dir="''${GETMEDIA_VIDEO_DIR:-$HOME/Videos}"
      audio_dir="''${GETMEDIA_AUDIO_DIR:-$HOME/Music}"

      # If the invocation looks like an audio grab (-t mp3, -x, --audio-format,
      # or a bare audio format token) sort it into ~/Music with an artist/title
      # layout; otherwise treat it as video into ~/Videos, foldered per site.
      mode="video"
      for arg in "$@"; do
        case "$arg" in
          -x | --extract-audio | --audio-format | mp3 | aac | flac | opus | m4a | wav | vorbis)
            mode="audio" ;;
        esac
      done

      if [ "$mode" = "audio" ]; then
        dest="$audio_dir"
        template="%(artist,uploader,channel)s/%(title)s [%(id)s].%(ext)s"
      else
        dest="$video_dir"
        template="%(extractor_key)s/%(title)s [%(id)s].%(ext)s"
      fi
      mkdir -p "$dest"

      exec yt-dlp \
        --paths "$dest" \
        --output "$template" \
        --trim-filenames 150 \
        --embed-metadata \
        --embed-thumbnail \
        --concurrent-fragments 4 \
        --ignore-errors \
        --no-playlist \
        "$@"
    '';
  };
in
{
  home.packages = [ getmedia ];
}
