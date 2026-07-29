{ pkgs, lib, ... }:

let
  replayDir = "Videos/Replays";

  # After each save, emit a shareable mp4 alongside the mkv master: desktop (track 0) mixed with
  # mic, video stream-copied, audio re-encoded.
  onSave = pkgs.writeShellScript "gsr-on-save" ''
    src="$1"
    case "$src" in
      *.mkv)
        out="''${src%.mkv}.mp4"
        n=$(${pkgs.ffmpeg}/bin/ffprobe -v error -select_streams a \
              -show_entries stream=index -of csv=p=0 "$src" | wc -l)
        if [ "$n" -ge 2 ]; then
          ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$src" \
            -filter_complex "[0:a:0][0:a:$((n - 1))]amix=inputs=2:normalize=0[a]" \
            -map 0:v:0 -map "[a]" -c:v copy -c:a aac -b:a 192k \
            -movflags +faststart "$out" >/dev/null 2>&1
        else
          ${pkgs.ffmpeg}/bin/ffmpeg -y -i "$src" -map 0:v:0 -map 0:a:0 \
            -c:v copy -c:a aac -b:a 192k -movflags +faststart "$out" >/dev/null 2>&1
        fi
        ${pkgs.libnotify}/bin/notify-send -a "GPU Screen Recorder" "Clip saved → mp4" "$out"
        ;;
      *)
        ${pkgs.libnotify}/bin/notify-send -a "GPU Screen Recorder" "Saved" "$src"
        ;;
    esac
  '';

  # Rolling replay buffer on the high-refresh monitor, falling back to the whole desktop if it
  # can't be resolved (focused capture is X11-only).
  replay = pkgs.writeShellScript "gsr-replay" ''
    ${pkgs.coreutils}/bin/sleep 2  # let pipewire + hyprland IPC come up
    monitor=$(hyprctl monitors -j 2>/dev/null \
      | ${pkgs.jq}/bin/jq -r '
          map(select(.disabled | not))
          | (map(select(.description | test("GIGABYTE"))) + .)[0].name // empty')
    # Each -a is its own mkv track (T1 desktop mix, T2 Spotify, T3 Helium, T4 Vesktop/Chromium, T5 mic); the on-save script assumes the mic is LAST, so keep default_input at the end.
    exec gpu-screen-recorder \
      -w "''${monitor:-screen}" \
      -f 60 \
      -a default_output \
      -a "app:spotify" \
      -a "app:alsa_playback.helium" \
      -a "app:Chromium" \
      -a default_input \
      -k h264 \
      -c mkv \
      -q very_high \
      -r 120 \
      -sc ${onSave} \
      -o "$HOME/${replayDir}"
  '';
in
{
  # GSR fails on a missing output path.
  home.file."${replayDir}/.keep".text = "";

  hydenix.hm.hyprland = {
    extraConfig = lib.mkAfter ''
      exec-once = ${replay}
    '';

    # "gpu-screen-rec" is the truncated process name; an unanchored -f would also hit gsr-kms-server.
    keybindings.extraConfig = lib.mkAfter ''
      $d=[$ut|Screen Recording]
      bindd = SUPER ALT, R, $d Clip last 30s (replay), exec, pkill --signal SIGRTMIN+2 gpu-screen-rec
      bindd = SUPER ALT, F, $d Save full replay buffer, exec, pkill --signal SIGUSR1 gpu-screen-rec
    '';
  };
}
