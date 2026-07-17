{ pkgs, ... }:

let
  # Thin yt-dlp wrapper that gives each download a clean per-site filename, auto-sorts into ~/Videos or ~/Music, and forwards extra flags to yt-dlp.
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

      # Audio-looking invocations (-x, --audio-format, a bare format token) sort into ~/Music by artist/title; otherwise video into ~/Videos foldered per site.
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
