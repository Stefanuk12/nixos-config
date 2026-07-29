{ pkgs, ... }:

let
  # noctalia's config.toml is a read-only store symlink, but it merges an app-writable
  # settings.toml from its state dir on top ("sidecar wins") and inotify-watches it, so that file
  # is the only supported way to move these at runtime. It also holds whatever the settings UI has
  # saved, hence tomlkit rather than truncating it.
  #
  # Both osd and notification are moved together: the bare media keys route through spotify-osd
  # -> notify-send, which is a notification rather than an OSD, and the two have separate
  # monitor lists.
  placer = pkgs.writers.writePython3Bin "noctalia-osd-place"
    {
      libraries = [ pkgs.python3Packages.tomlkit ];
      flakeIgnore = [ "E501" ];
    }
    ''
      import json
      import os
      import subprocess
      import sys

      import tomlkit

      HYPRCTL = "${pkgs.hyprland}/bin/hyprctl"
      SECTIONS = ("osd", "notification")

      STATE = os.path.join(
          os.environ.get("XDG_STATE_HOME", os.path.expanduser("~/.local/state")),
          "noctalia",
          "settings.toml",
      )


      def hypr(what):
          out = subprocess.check_output([HYPRCTL, "-j", what], text=True)
          return json.loads(out)


      def logical(monitor):
          scale = monitor.get("scale") or 1.0
          if scale <= 0:
              scale = 1.0
          return (monitor["width"] / scale, monitor["height"] / scale)


      def is_covered(monitor, clients):
          """True when something on this output is fullscreen or a borderless window filling it."""
          width, height = logical(monitor)
          for client in clients:
              if client.get("monitor") != monitor.get("id"):
                  continue
              if not client.get("mapped", True) or client.get("hidden"):
                  continue
              if (client.get("fullscreen") or 0) >= 2:
                  return True
              # Gated on floating: a lone *tiled* window also fills its output, which would
              # otherwise read as fullscreen on every single-window workspace.
              size = client.get("size") or [0, 0]
              if client.get("floating") and size[0] >= width and size[1] >= height:
                  return True
          return False


      def pick(monitors, clients):
          usable = [m for m in monitors if not m.get("disabled")]
          if not usable:
              return None

          focused = next((m for m in usable if m.get("focused")), usable[0])
          covered = [m for m in usable if is_covered(m, clients)]

          # Exactly one output busy (and somewhere else to go) -> get out of its way. Zero, all,
          # or several busy means there is no unambiguous refuge, so follow focus instead.
          if len(covered) == 1 and len(usable) > 1:
              busy = covered[0].get("name")
              elsewhere = [m for m in usable if m.get("name") != busy]
              return next(
                  (m for m in elsewhere if m.get("focused")), elsewhere[0]
              ).get("name")

          return focused.get("name")


      def apply(name):
          try:
              with open(STATE) as handle:
                  doc = tomlkit.parse(handle.read())
          except FileNotFoundError:
              doc = tomlkit.document()

          changed = False
          for section_name in SECTIONS:
              section = doc.get(section_name)
              if section is None:
                  section = tomlkit.table()
                  doc[section_name] = section
              if list(section.get("monitors", [])) != [name]:
                  section["monitors"] = [name]
                  changed = True

          if not changed:
              return False

          tmp = STATE + ".tmp"
          with open(tmp, "w") as handle:
              handle.write(tomlkit.dumps(doc))
          os.replace(tmp, STATE)
          return True


      def main():
          try:
              monitors = hypr("monitors")
              clients = hypr("clients")
          except (subprocess.CalledProcessError, json.JSONDecodeError):
              return

          target = pick(monitors, clients)
          if target and apply(target):
              print("osd/notifications -> " + target, file=sys.stderr)


      if __name__ == "__main__":
          main()
    '';

  watcher = pkgs.writeShellApplication {
    name = "noctalia-osd-follow";
    runtimeInputs = [
      pkgs.socat
      placer
    ];
    text = ''
      set -uo pipefail

      socket="$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/.socket2.sock"

      noctalia-osd-place || true
      socat -u "UNIX-CONNECT:$socket" - | while read -r line; do
        case "$line" in
          fullscreen\>\>* | openwindow\>\>* | closewindow\>\>* | movewindow\>\>* \
          | focusedmon\>\>* | activewindow\>\>* | workspace\>\>* \
          | monitoradded\>\>* | monitorremoved\>\>*)
            noctalia-osd-place || true
            ;;
        esac
      done
    '';
  };
in
{
  home.packages = [ watcher ];

  systemd.user.services.noctalia-osd-follow = {
    Unit = {
      Description = "Keep noctalia's OSD and notifications off a fullscreen output";
      PartOf = [ "graphical-session.target" ];
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${watcher}/bin/noctalia-osd-follow";
      Restart = "on-failure";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
