{ pkgs, lib, ... }:

let
  # Saved clips land here (~ expanded by the shell at runtime).
  replayDir = "Videos/Replays";

  # Runs after each save; for an .mkv replay it also emits a shareable mp4 mixing desktop (track 0) + mic, stream-copying video and re-encoding audio, keeping both (mkv master, mp4 shareable).
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

  # Arm the rolling replay buffer on the high-refresh gaming monitor, falling back to whole-desktop capture if it can't be resolved (focused capture is X11-only).
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
  # Ensure the output directory exists so GSR never fails on a missing path.
  home.file."${replayDir}/.keep".text = "";

  hydenix.hm.hyprland = {
    extraConfig = lib.mkAfter ''
      # GPU Screen Recorder: keep the last 120s buffered, armed at login.
      exec-once = ${replay}
    '';

    # Match the truncated process name "gpu-screen-rec" (nixpkgs wraps + truncates the binary, and an unanchored -f would also hit gsr-kms-server); bindd shows these in HyDE's cheatsheet under $d's category.
    keybindings.extraConfig = lib.mkAfter ''
      $d=[$ut|Screen Recording]
      # SUPER+ALT+R: clip the last 30 seconds
      bindd = SUPER ALT, R, $d Clip last 30s (replay), exec, pkill --signal SIGRTMIN+2 gpu-screen-rec
      # SUPER+ALT+F: save the full buffer (up to 120s)
      bindd = SUPER ALT, F, $d Save full replay buffer, exec, pkill --signal SIGUSR1 gpu-screen-rec
    '';
  };
}
