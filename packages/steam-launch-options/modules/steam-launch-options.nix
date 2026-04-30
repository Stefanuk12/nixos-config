{ config, lib, pkgs, ... }:

let
  cfg = config.programs.steam-launch-options;

  python = pkgs.python3.withPackages (ps: [ ps.vdf ]);

  optionsJson = pkgs.writeText "steam-launch-options.json"
    (builtins.toJSON cfg.appLaunchOptions);

  patcher-py = pkgs.writeText "patch-steam-launch-options.py" ''
    import glob
    import json
    import os
    import re
    import subprocess
    import sys
    import time
    from pathlib import Path

    import vdf


    SECTION_RE = re.compile(r'^\s*"([^"]+)"\s*$')
    LAUNCH_OPTIONS_RE = re.compile(
        r'^(?P<indent>\s*)"LaunchOptions"\s+"(?:[^"\\]|\\.)*"\s*$'
    )


    def vdf_escape(s):
        return s.replace("\\", "\\\\").replace('"', '\\"')


    def find_app_block(lines, app_id):
        section_stack = []
        pending = None
        start = None
        for i, line in enumerate(lines):
            stripped = line.strip()
            if stripped == "{":
                if pending is not None:
                    section_stack.append(pending)
                    pending = None
                    if (
                        len(section_stack) >= 2
                        and section_stack[-1] == app_id
                        and section_stack[-2] == "apps"
                    ):
                        start = i
                continue
            if stripped == "}":
                if section_stack:
                    popped = section_stack.pop()
                    if start is not None and popped == app_id:
                        return start, i
                continue
            m = SECTION_RE.match(line)
            pending = m.group(1) if m else None
        return None, None


    def set_launch_options(text, app_id, new_value):
        lines = text.split("\n")
        start, end = find_app_block(lines, app_id)
        if start is None:
            return text, False

        escaped = vdf_escape(new_value)
        for i in range(start + 1, end):
            m = LAUNCH_OPTIONS_RE.match(lines[i])
            if m:
                new_line = (
                    m.group("indent") + '"LaunchOptions"\t\t"' + escaped + '"'
                )
                if lines[i] == new_line:
                    return text, False
                lines[i] = new_line
                return "\n".join(lines), True

        indent = "\t"
        for i in range(start + 1, end):
            if lines[i].strip():
                indent = lines[i][: len(lines[i]) - len(lines[i].lstrip())]
                break
        lines.insert(end, indent + '"LaunchOptions"\t\t"' + escaped + '"')
        return "\n".join(lines), True


    def steam_running():
        try:
            subprocess.check_output(
                ["pgrep", "-x", "steam"], stderr=subprocess.DEVNULL
            )
            return True
        except subprocess.CalledProcessError:
            return False


    def wait_for_steam_gone(timeout=180, stable_secs=5):
        deadline = time.time() + timeout
        stable_start = None
        while time.time() < deadline:
            if steam_running():
                stable_start = None
                time.sleep(2)
                continue
            if stable_start is None:
                stable_start = time.time()
                print("Steam appears gone — waiting "
                      + str(stable_secs) + "s to confirm...")
            if time.time() - stable_start >= stable_secs:
                return True
            time.sleep(1)
        return False


    def patch_file(path, overrides):
        text = path.read_text(encoding="utf-8")
        try:
            cfg = vdf.loads(text)
            apps = cfg["UserLocalConfigStore"]["Software"]["Valve"]["Steam"]["apps"]
        except (KeyError, SyntaxError) as e:
            print("[skip] " + str(path) + ": parse error: " + repr(e))
            return False

        new_text = text
        file_changed = False
        for app_id, new_opts in overrides.items():
            if app_id not in apps:
                print("[skip] " + path.parent.parent.name
                      + " " + app_id + ": app not in this account's library")
                continue
            current = apps[app_id].get("LaunchOptions")
            if current == new_opts:
                print("[ok]  " + path.parent.parent.name
                      + " " + app_id + ": already matches")
                continue
            new_text, changed = set_launch_options(new_text, app_id, new_opts)
            if changed:
                print("[set] " + path.parent.parent.name
                      + " " + app_id + ": " + repr(new_opts))
                file_changed = True
            else:
                print("[warn] " + path.parent.parent.name
                      + " " + app_id + ": couldn't locate app block")

        if file_changed:
            path.write_text(new_text, encoding="utf-8")
        return file_changed


    def main():
        if not wait_for_steam_gone():
            print("Timed out waiting for Steam to exit cleanly — giving up.")
            sys.exit(0)

        overrides = json.loads(Path(sys.argv[1]).read_text(encoding="utf-8"))

        home = os.environ["HOME"]
        paths = sorted(
            Path(p)
            for p in glob.glob(
                home + "/.steam/steam/userdata/*/config/localconfig.vdf"
            )
        )
        if not paths:
            print("No localconfig.vdf found.")
            sys.exit(0)

        any_changed = any(patch_file(p, overrides) for p in paths)
        if not any_changed:
            print("All Steam launch options already match.")


    if __name__ == "__main__":
        main()
  '';

  patch-steam-launch-options =
    pkgs.writeShellScriptBin "patch-steam-launch-options" ''
      exec ${python}/bin/python3 ${patcher-py} ${optionsJson}
    '';

in
{
  options.programs.steam-launch-options = {
    enable = lib.mkEnableOption "Declarative Steam launch options patcher";

    appLaunchOptions = lib.mkOption {
      type = lib.types.attrsOf lib.types.str;
      default = { };
      description = ''
        Steam AppID -> launch options string. Backslash-escape inner
        quotes the same way you would in the Steam UI.
      '';
      example = lib.literalExpression ''
        {
          "381210" = ''\'\'WINEDLLOVERRIDES=\"dxgi=n,b\" %command% -dx11''\'\';
        }
      '';
    };

    userDataIds = lib.mkOption {
      type = lib.types.listOf lib.types.str;
      default = [ ];
      description = ''
        Steam userdata IDs whose `localconfig.vdf` should be watched and
        patched. Find them with `ls ~/.steam/steam/userdata/`.
      '';
      example = lib.literalExpression ''[ "280400742" ]'';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [ patch-steam-launch-options ];

    # Try on every `home-manager switch` — usually a no-op because Steam
    # is running, but catches the rare case where it isn't.
    home.activation.patchSteamLaunchOptions =
      lib.hm.dag.entryAfter [ "writeBoundary" ] ''
        $DRY_RUN_CMD ${patch-steam-launch-options}/bin/patch-steam-launch-options || true
      '';

    # Ensure the path watcher is actually running after a switch. Without
    # this it stays `inactive (dead)` until next login.
    home.activation.startSteamLaunchPath =
      lib.hm.dag.entryAfter [ "reloadSystemd" ] ''
        $DRY_RUN_CMD ${pkgs.systemd}/bin/systemctl --user start \
          patch-steam-launch-options.path || true
      '';

    systemd.user.services.patch-steam-launch-options = {
      Unit.Description = "Apply declarative Steam launch options";
      Service = {
        Type = "oneshot";
        # The patcher itself blocks until Steam has been gone for 5
        # stable seconds (or 3-minute hard timeout).
        TimeoutStartSec = "300s";
        ExecStart =
          "${patch-steam-launch-options}/bin/patch-steam-launch-options";
      };
    };

    systemd.user.paths.patch-steam-launch-options = {
      Unit.Description = "Watch Steam localconfig.vdf for changes";
      Path = {
        PathChanged = map
          (id: "%h/.steam/steam/userdata/${id}/config/localconfig.vdf")
          cfg.userDataIds;
        Unit = "patch-steam-launch-options.service";
      };
      Install.WantedBy = [ "default.target" ];
    };
  };
}
