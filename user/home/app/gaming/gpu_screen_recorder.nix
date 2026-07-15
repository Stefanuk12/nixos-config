{ pkgs, lib, ... }:

let
  # Saved clips land here. ~ is expanded by the shell at runtime.
  replayDir = "Videos/Replays";

  # Runs after each save ($1 = file path, $2 = type). For a replay (.mkv with
  # the separate per-app tracks) it also emits a shareable single-track mp4 that
  # mixes the full desktop (track 0) with the mic into one channel. The per-app
  # stems are already part of the desktop mix, so combining only desktop+mic
  # yields every source exactly once (no double-counting). Video is stream-
  # copied; only audio is re-encoded. Both files are kept: mkv = editable
  # master, mp4 = shareable.
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

  # Arm the rolling replay buffer on the high-refresh gaming monitor, falling
  # back to whole-desktop capture if it can't be resolved (e.g. single screen).
  # `focused` capture is X11-only, so the target monitor is picked up front.
  replay = pkgs.writeShellScript "gsr-replay" ''
    ${pkgs.coreutils}/bin/sleep 2  # let pipewire + hyprland IPC come up
    monitor=$(hyprctl monitors -j 2>/dev/null \
      | ${pkgs.jq}/bin/jq -r '
          map(select(.disabled | not))
          | (map(select(.description | test("GIGABYTE"))) + .)[0].name // empty')
    # Each -a is its own track in the (mkv) clip. GSR can't auto-split every
    # app, so we name them: T1 full desktop mix (catch-all for games and
    # anything unlisted), T2 Spotify, T3 Helium (reports itself as
    # "alsa_playback.helium"), T4 Vesktop (reports the generic Electron name
    # "Chromium"), and T5 the mic. The on-save script assumes the mic is the
    # LAST track, so keep default_input at the end. Confirm live names with
    # `--list-application-audio` while the app runs.
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

    # nixpkgs wraps the binary, so it runs as a /nix/store/…/.wrapped path and
    # its name is truncated to "gpu-screen-reco". That defeats GSR's documented
    # `pkill -f '^gpu-screen-recorder'`, and an unanchored -f match would also
    # hit gsr-kms-server (same store path). Match the process name instead — it
    # uniquely targets the recorder and never the kms helper.
    # `bindd` (bind-with-description) makes these appear in HyDE's SUPER+/
    # keybind cheatsheet. $d is HyDE's category variable (defined in the
    # keybindings.conf prepended before this block); setting it here groups
    # both binds under a "Screen Recording" section in the cheatsheet.
    keybindings.extraConfig = lib.mkAfter ''
      $d=[$ut|Screen Recording]
      # SUPER+ALT+R: clip the last 30 seconds
      bindd = SUPER ALT, R, $d Clip last 30s (replay), exec, pkill --signal SIGRTMIN+2 gpu-screen-rec
      # SUPER+ALT+F: save the full buffer (up to 120s)
      bindd = SUPER ALT, F, $d Save full replay buffer, exec, pkill --signal SIGUSR1 gpu-screen-rec
    '';
  };
}
