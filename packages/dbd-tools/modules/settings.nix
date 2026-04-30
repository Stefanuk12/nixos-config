{ config, lib, pkgs, ... }:

let
  cfg = config.programs.dbd;

  # Render a Nix value to its UE-ini string form.
  formatValue =
    v:
    if builtins.isBool v then
      (if v then "True" else "False")
    else if builtins.isInt v then
      toString v
    else if builtins.isFloat v then
      toString v
    else if builtins.isString v then
      v
    else
      throw "programs.dbd.settings: unsupported value type for ${builtins.toJSON v}";

  formattedSettings = builtins.mapAttrs (
    _file: builtins.mapAttrs (_section: builtins.mapAttrs (_key: formatValue))
  ) cfg.settings;

  formattedAxisMappings = map (m: {
    name = m.name;
    scale = toString (m.scale + 0.0);
    key = m.key;
  }) cfg.axisMappings;

  boolStr = b: if b then "True" else "False";
  formattedActionMappings = map (m: {
    name = m.name;
    shift = boolStr m.shift;
    ctrl = boolStr m.ctrl;
    alt = boolStr m.alt;
    cmd = boolStr m.cmd;
    key = m.key;
  }) cfg.actionMappings;

  overrides-json = pkgs.writeText "dbd-settings.json" (builtins.toJSON {
    files = formattedSettings;
    axisMappings = formattedAxisMappings;
    actionMappings = formattedActionMappings;
  });

  patcher-py = pkgs.writeText "patch-dbd-ini.py" ''
    import json
    import re
    import sys
    from pathlib import Path

    SECTION_RE = re.compile(r"^\[(.+)\]\s*$")
    KV_RE = re.compile(r"^([^=\[\]\s]+)=(.*)$")
    AXIS_RE = re.compile(
        r'^AxisMappings=\(AxisName="([^"]+)",Scale=([^,]+),Key=(.+)\)\s*$'
    )
    ACTION_RE = re.compile(
        r'^ActionMappings=\(ActionName="([^"]+)",'
        r'bShift=(True|False),bCtrl=(True|False),'
        r'bAlt=(True|False),bCmd=(True|False),Key=(.+)\)\s*$'
    )
    ENHANCED_INPUT_SECTION = "/Script/EnhancedInput.EnhancedPlayerInput"


    def write_with_trailing_eol(path, lines, eol):
        text = eol.join(lines)
        if not text.endswith(eol):
            text += eol
        path.write_bytes(text.encode("utf-8"))


    def format_axis_line(m):
        return ('AxisMappings=(AxisName="' + m["name"] + '",Scale='
                + m["scale"] + ',Key=' + m["key"] + ')')


    def format_action_line(m):
        return ('ActionMappings=(ActionName="' + m["name"]
                + '",bShift=' + m["shift"]
                + ',bCtrl=' + m["ctrl"]
                + ',bAlt=' + m["alt"]
                + ',bCmd=' + m["cmd"]
                + ',Key=' + m["key"] + ')')


    def render_new_file(overrides, eol):
        lines = []
        for section, kvs in overrides.items():
            if not kvs:
                continue
            if lines:
                lines.append("")
            lines.append("[" + section + "]")
            for k, v in kvs.items():
                lines.append(k + "=" + v)
        return eol.join(lines) + eol


    def patch_existing(path, overrides):
        raw = path.read_bytes()
        eol = "\r\n" if b"\r\n" in raw else "\n"
        lines = raw.decode("utf-8").split(eol)

        applied = set()
        insert_after = {}
        section_seen = set()
        current = None

        for i, line in enumerate(lines):
            m = SECTION_RE.match(line)
            if m:
                current = m.group(1)
                section_seen.add(current)
                insert_after[current] = i
                continue
            kv = KV_RE.match(line)
            if current and kv:
                key = kv.group(1)
                insert_after[current] = i
                new_val = overrides.get(current, {}).get(key)
                if new_val is not None:
                    lines[i] = key + "=" + new_val
                    applied.add((current, key))

        missing = {}
        for section, kvs in overrides.items():
            for key, val in kvs.items():
                if (section, key) not in applied:
                    missing.setdefault(section, []).append((key, val))

        existing = sorted(
            [(s, kv) for s, kv in missing.items() if s in section_seen],
            key=lambda x: insert_after[x[0]],
            reverse=True,
        )
        for section, kvs in existing:
            at = insert_after[section] + 1
            for k, v in reversed(kvs):
                lines.insert(at, k + "=" + v)

        for section, kvs in missing.items():
            if section in section_seen:
                continue
            if lines and lines[-1] != "":
                lines.append("")
            lines.append("[" + section + "]")
            for k, v in kvs:
                lines.append(k + "=" + v)

        write_with_trailing_eol(path, lines, eol)


    def merge_into_enhanced_input(
        path, mappings, line_re, parse_match, declared_match, format_fn, label
    ):
        """Merge typed entries into the EnhancedInput section.

        For each declared mapping, find an existing line whose
        `parse_match(re.Match)` equals `declared_match(mapping)`. If
        found, replace; otherwise append. Existing lines that aren't
        matched are left untouched.
        """
        if not mappings:
            return

        if not path.exists():
            new_lines = ["[" + ENHANCED_INPUT_SECTION + "]"] + [
                format_fn(m) for m in mappings
            ]
            write_with_trailing_eol(path, new_lines, "\r\n")
            print("[" + label + "] " + path.name + ": created with "
                  + str(len(mappings)) + " mapping(s)")
            return

        raw = path.read_bytes()
        eol = "\r\n" if b"\r\n" in raw else "\n"
        lines = raw.decode("utf-8").split(eol)

        section_start = None
        section_end = None
        current = None
        for i, line in enumerate(lines):
            m = SECTION_RE.match(line)
            if m:
                if current == ENHANCED_INPUT_SECTION:
                    section_end = i
                    break
                current = m.group(1)
                if current == ENHANCED_INPUT_SECTION:
                    section_start = i
        if current == ENHANCED_INPUT_SECTION and section_end is None:
            section_end = len(lines)

        if section_start is None:
            if lines and lines[-1] != "":
                lines.append("")
            lines.append("[" + ENHANCED_INPUT_SECTION + "]")
            for m in mappings:
                lines.append(format_fn(m))
            write_with_trailing_eol(path, lines, eol)
            print("[" + label + "] " + path.name + ": appended section with "
                  + str(len(mappings)) + " mapping(s)")
            return

        existing = {}
        for i in range(section_start + 1, section_end):
            m = line_re.match(lines[i])
            if m:
                existing[parse_match(m)] = i

        n_replaced = 0
        n_unchanged = 0
        appendages = []
        for mapping in mappings:
            new_line = format_fn(mapping)
            match_key = declared_match(mapping)
            if match_key in existing:
                idx = existing[match_key]
                if lines[idx] == new_line:
                    n_unchanged += 1
                else:
                    lines[idx] = new_line
                    n_replaced += 1
            else:
                appendages.append(new_line)

        insert_at = section_end
        while insert_at > section_start + 1 and lines[insert_at - 1] == "":
            insert_at -= 1

        for i, line in enumerate(appendages):
            lines.insert(insert_at + i, line)

        write_with_trailing_eol(path, lines, eol)
        print("[" + label + "] " + path.name + ": "
              + str(n_replaced) + " replaced, "
              + str(len(appendages)) + " appended, "
              + str(n_unchanged) + " unchanged")


    def merge_axis_mappings(path, mappings):
        merge_into_enhanced_input(
            path,
            mappings,
            AXIS_RE,
            lambda m: (m.group(1), m.group(3)),
            lambda d: (d["name"], d["key"]),
            format_axis_line,
            "axis",
        )


    def merge_action_mappings(path, mappings):
        merge_into_enhanced_input(
            path,
            mappings,
            ACTION_RE,
            lambda m: (m.group(1), m.group(2), m.group(3),
                       m.group(4), m.group(5), m.group(6)),
            lambda d: (d["name"], d["shift"], d["ctrl"],
                       d["alt"], d["cmd"], d["key"]),
            format_action_line,
            "action",
        )


    def patch_one(path, overrides):
        if not any(kvs for kvs in overrides.values()):
            return
        if path.exists():
            patch_existing(path, overrides)
            print("[patched] " + path.name)
        else:
            path.write_bytes(render_new_file(overrides, "\r\n").encode("utf-8"))
            print("[created] " + path.name)


    if __name__ == "__main__":
        config_dir = Path(sys.argv[1])
        if not config_dir.exists():
            print("DBD config dir not found at " + str(config_dir))
            print("Launch Dead by Daylight at least once to generate it.")
            sys.exit(0)

        data = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
        file_overrides = data.get("files", {})
        axis_mappings = data.get("axisMappings", [])
        action_mappings = data.get("actionMappings", [])

        n_settings = 0
        for filename, file_settings in file_overrides.items():
            patch_one(config_dir / filename, file_settings)
            n_settings += sum(len(v) for v in file_settings.values())

        merge_axis_mappings(config_dir / "Input.ini", axis_mappings)
        merge_action_mappings(config_dir / "Input.ini", action_mappings)

        print("Done: " + str(n_settings) + " setting(s) across "
              + str(len(file_overrides)) + " file(s); "
              + str(len(axis_mappings)) + " axis mapping(s); "
              + str(len(action_mappings)) + " action mapping(s).")
  '';

  patch-dbd-settings = pkgs.writeShellScriptBin "patch-dbd-settings" ''
    set -euo pipefail
    exec ${pkgs.python3}/bin/python3 ${patcher-py} "${cfg.configDir}" ${overrides-json}
  '';

  dbd-launch = pkgs.writeShellScriptBin "dbd-launch" ''
    ${patch-dbd-settings}/bin/patch-dbd-settings || true
    exec "$@"
  '';

  # Per-key value type: any UE-serialisable scalar.
  scalarType = lib.types.oneOf [
    lib.types.bool
    lib.types.int
    lib.types.float
    lib.types.str
  ];

  axisMappingType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "AxisName of the binding (e.g. \"MoveForwardSurvivor\").";
      };
      scale = lib.mkOption {
        type = lib.types.either lib.types.int lib.types.float;
        description = ''
          Axis scale (typically 1.0 or -1.0). Integers are coerced to float
          and rendered with six decimals (e.g. 1 -> "1.000000").
        '';
      };
      key = lib.mkOption {
        type = lib.types.str;
        description = "Key bound to the axis (e.g. \"W\", \"Gamepad_LeftY\").";
      };
    };
  };

  actionMappingType = lib.types.submodule {
    options = {
      name = lib.mkOption {
        type = lib.types.str;
        description = "ActionName of the binding (e.g. \"Interact_Camper\").";
      };
      shift = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require Shift modifier.";
      };
      ctrl = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require Ctrl modifier.";
      };
      alt = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require Alt modifier.";
      };
      cmd = lib.mkOption {
        type = lib.types.bool;
        default = false;
        description = "Require Cmd modifier (Mac).";
      };
      key = lib.mkOption {
        type = lib.types.str;
        description = "Key bound to the action.";
      };
    };
  };

in
{
  options.programs.dbd = {
    enable = lib.mkEnableOption "Dead by Daylight declarative config patcher";

    configDir = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/Steam/steamapps/compatdata/381210/pfx/drive_c/users/steamuser/AppData/Local/DeadByDaylight/Saved/Config/WindowsClient";
      description = ''
        Path to DBD's config directory inside the Proton prefix. Shell
        expansion is applied at runtime, so $HOME is fine.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf (lib.types.attrsOf scalarType));
      default = { };
      description = ''
        Three-level attrset: filename -> section -> key -> value.

        The patcher overlays each declared file in `configDir` with these
        values, preserving everything else (other keys, blank lines,
        comments, CRLF endings). Files that don't exist yet are created
        with CRLF endings on first run.

        Type-aware formatting:
          bool   -> "True" / "False"     (UE convention)
          int    -> e.g. 165             (no decimals)
          float  -> e.g. 165.000000      (Nix's toString gives 6 decimals)
          string -> verbatim

        CAVEAT for Input.ini: keys like ActionMappings/AxisMappings appear
        many times with different tuple values. Don't set those here —
        the patcher would replace ALL occurrences with one value, wiping
        bindings. Use `axisMappings` for axis bindings instead.
      '';
      example = lib.literalExpression ''
        {
          "GameUserSettings.ini" = {
            "/Script/DeadByDaylight.DBDGameUserSettings" = {
              FieldOfView = 95;
              UseHeadphones = false;
            };
          };
          "Engine.ini" = {
            "/Script/Engine.Engine" = {
              FixedFrameRate = 240;
              bUseFixedFrameRate = true;
            };
          };
        }
      '';
    };

    axisMappings = lib.mkOption {
      type = lib.types.listOf axisMappingType;
      default = [ ];
      description = ''
        Axis bindings to merge into Input.ini's
        [/Script/EnhancedInput.EnhancedPlayerInput] section.

        Merge semantics: matched on (name, key). If a binding for that
        pair already exists, its line is rewritten with the new scale.
        Otherwise a new line is appended. Existing bindings not listed
        here are left untouched — declare overrides only.

        Same axis can be bound to multiple keys, and same key can be
        bound to multiple axes — (name, key) is the unique identifier.
      '';
      example = lib.literalExpression ''
        [
          { name = "MoveForwardSurvivor"; scale =  1.0; key = "Up"; }
          { name = "MoveForwardSurvivor"; scale = -1.0; key = "Down"; }
        ]
      '';
    };

    actionMappings = lib.mkOption {
      type = lib.types.listOf actionMappingType;
      default = [ ];
      description = ''
        Action bindings to merge into Input.ini's
        [/Script/EnhancedInput.EnhancedPlayerInput] section.

        Merge semantics: matched on the full tuple (name, shift, ctrl,
        alt, cmd, key). If an existing line matches all six fields, it's
        a no-op; otherwise the entry is appended. Existing bindings not
        listed here are left untouched.

        Modifier flags default to `false`, so you only need to specify
        the ones you want.
      '';
      example = lib.literalExpression ''
        [
          { name = "Interact_Camper"; key = "LeftMouseButton"; }
          { name = "Atlanta_Back"; alt = true; key = "BackSpace"; }
        ]
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      patch-dbd-settings
      dbd-launch
    ];

    # Re-apply on every `home-manager switch`. DBD overwrites these files
    # whenever it saves settings, so you can also run `patch-dbd-settings`
    # manually after closing the game.
    home.activation.patchDbdSettings = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${patch-dbd-settings}/bin/patch-dbd-settings || true
    '';
  };
}
