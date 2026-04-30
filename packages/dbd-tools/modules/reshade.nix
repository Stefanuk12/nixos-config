{ config, lib, pkgs, ... }:

let
  cfg = config.programs.dbd.reshade;

  # =====================================================================
  # Source pins
  # =====================================================================

  reshade-version = "6.3.3";

  reshade-bin = pkgs.fetchurl {
    url = "https://reshade.me/downloads/ReShade_Setup_${reshade-version}.exe";
    hash = "sha256-TdvcAyqRS1Z92PjKpZpbeFwytJDAujxQQPVEgkyYCmw=";
  };

  reshade-shaders = pkgs.fetchFromGitHub {
    owner = "crosire";
    repo = "reshade-shaders";
    rev = "6db142b4b1a05c764222e5b0bd9a644b7ccfe1dc";
    hash = "sha256-WqT4eU8ZlGwKEgUEGlivz+35GprKX4goBeLnp9D5lTY=";
  };

  prod80-shaders = pkgs.fetchFromGitHub {
    owner = "prod80";
    repo = "prod80-ReShade-Repository";
    rev = "1c2ed5b093b03c558bfa6aea45c2087052e99554";
    hash = "sha256-EM9WxpbN0tUB9yjZFwWtY1l8um7jvMfC2eenEl2amF8=";
  };

  dbd-presets = pkgs.fetchFromGitHub {
    owner = "Joolace";
    repo = "dbd-reshade";
    rev = "5e84695c1fbf2402390feb3d96935e79ceff7157";
    hash = "sha256-7Qxbh4IsvdJj7e/lyJww1R3PL/1dCW3TVwLVrxZ69/g=";
  };

  steaxs-presets = pkgs.fetchFromGitHub {
    owner = "steaxss";
    repo = "STEAXS-FILTER-PACK";
    rev = "5beb3b861d30b25047bd534cf7178d4222994b6f";
    hash = "sha256-NXirUblL5gs7hN+0ZpYo7C+ItUVgNDK25+nSj1eMaN8=";
  };

  # =====================================================================
  # Settings: defaults merged with user overrides
  # =====================================================================

  defaultSettings = {
    GENERAL = {
      EffectSearchPaths = ".\\reshade-shaders\\Shaders";
      TextureSearchPaths = ".\\reshade-shaders\\Textures";
      PresetPath = ".\\reshade-presets";
      PresetTransitionDelay = 1000;
      SkipLoadingDisabledEffects = 1;
    };
    INPUT = {
      KeyOverlay = "115,0,0,0"; # F4
      ForceShortcutModifiers = 1;
      GamepadNavigation = 1;
    };
    OVERLAY = {
      TutorialProgress = 4;
      ShowFPS = 1;
      ShowClock = 0;
    };
  };

  finalSettings = lib.recursiveUpdate defaultSettings cfg.settings;

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
      throw "programs.dbd.reshade.settings: unsupported value type for ${builtins.toJSON v}";

  formattedSettings =
    builtins.mapAttrs (_section: builtins.mapAttrs (_key: formatValue)) finalSettings;

  # Render the full ReShade.ini text (for first-install template).
  renderIni =
    settings:
    lib.concatStringsSep "\n\n" (
      lib.mapAttrsToList (
        section: kvs:
        "[${section}]\n"
        + lib.concatStringsSep "\n" (lib.mapAttrsToList (k: v: "${k}=${v}") kvs)
      ) settings
    )
    + "\n";

  reshade-ini = pkgs.writeText "ReShade.ini" (renderIni formattedSettings);

  overrides-json = pkgs.writeText "reshade-settings.json" (builtins.toJSON formattedSettings);

  scalarType = lib.types.oneOf [
    lib.types.bool
    lib.types.int
    lib.types.float
    lib.types.str
  ];

  # =====================================================================
  # Patcher: merges declared settings into an existing ReShade.ini
  # =====================================================================

  patcher-py = pkgs.writeText "patch-reshade-ini.py" ''
    """Merge declared settings into an existing ReShade.ini.

    Preserves line endings, blank lines, comments, and original key order.
    Replaces existing keys in place; appends keys not present at the end of
    their section; creates missing sections at EOF.
    """
    import json
    import re
    import sys
    from pathlib import Path

    SECTION_RE = re.compile(r"^\[(.+)\]\s*$")
    KV_RE = re.compile(r"^([^=\[\]\s]+)=(.*)$")


    def patch(path, overrides):
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

        text = eol.join(lines)
        if not text.endswith(eol):
            text += eol
        path.write_bytes(text.encode("utf-8"))


    if __name__ == "__main__":
        ini_path = Path(sys.argv[1])
        if not ini_path.exists():
            print("ReShade.ini not found at " + str(ini_path))
            print("Run install-reshade-dbd to install ReShade first.")
            sys.exit(0)

        overrides = json.loads(Path(sys.argv[2]).read_text(encoding="utf-8"))
        patch(ini_path, overrides)

        n = sum(len(v) for v in overrides.values())
        print("Patched ReShade.ini: applied " + str(n) + " setting(s).")
  '';

  patch-reshade-ini = pkgs.writeShellScriptBin "patch-reshade-ini" ''
    set -euo pipefail
    INI_PATH="${cfg.gamePath}/ReShade.ini"
    exec ${pkgs.python3}/bin/python3 ${patcher-py} "$INI_PATH" ${overrides-json}
  '';

  # =====================================================================
  # Install / uninstall scripts
  # =====================================================================

  install-reshade-dbd = pkgs.writeShellScriptBin "install-reshade-dbd" ''
    set -euo pipefail
    GAME_DIR="${cfg.gamePath}"

    if [ ! -d "$GAME_DIR" ]; then
      echo "ERROR: DBD not found at $GAME_DIR"
      echo "Make sure Dead by Daylight is installed via Steam."
      exit 1
    fi

    echo "=== Installing ReShade for Dead by Daylight ==="

    # --- Shaders ---
    echo "[1/4] Linking shaders..."
    mkdir -p "$GAME_DIR/reshade-shaders/Shaders"
    mkdir -p "$GAME_DIR/reshade-shaders/Textures"

    for f in ${reshade-shaders}/Shaders/*; do
      ln -sf "$f" "$GAME_DIR/reshade-shaders/Shaders/"
    done
    for f in ${reshade-shaders}/Textures/*; do
      ln -sf "$f" "$GAME_DIR/reshade-shaders/Textures/"
    done

    if [ -d "${prod80-shaders}/Shaders" ]; then
      for f in ${prod80-shaders}/Shaders/*; do
        ln -sf "$f" "$GAME_DIR/reshade-shaders/Shaders/"
      done
    fi
    if [ -d "${prod80-shaders}/Textures" ]; then
      for f in ${prod80-shaders}/Textures/*; do
        ln -sf "$f" "$GAME_DIR/reshade-shaders/Textures/"
      done
    fi

    # --- Presets ---
    echo "[2/4] Copying presets..."
    mkdir -p "$GAME_DIR/reshade-presets"
    find ${dbd-presets} -name "*.ini" -exec cp -n {} "$GAME_DIR/reshade-presets/" \;
    find ${steaxs-presets} -name "*.ini" -exec cp -n {} "$GAME_DIR/reshade-presets/" \;

    # --- ReShade DLL ---
    echo "[3/4] Installing ReShade DLL..."
    ${pkgs.p7zip}/bin/7z e -y -o/tmp/reshade-extract ${reshade-bin} \
      "ReShade64.dll" > /dev/null 2>&1 || true

    if [ -f /tmp/reshade-extract/ReShade64.dll ]; then
      cp /tmp/reshade-extract/ReShade64.dll "$GAME_DIR/dxgi.dll"
      rm -rf /tmp/reshade-extract
      echo "  ReShade64.dll -> dxgi.dll"
    else
      echo "ERROR: Failed to extract ReShade64.dll"
      echo "You may need to download it manually from https://reshade.me"
      exit 1
    fi

    # --- Initial ReShade.ini ---
    # Only write a fresh template if the file doesn't already exist.
    # If it does, the patcher below merges declared settings non-destructively
    # so any in-overlay tweaks for keys we don't declare are preserved.
    echo "[4/4] Writing ReShade.ini..."
    if [ ! -f "$GAME_DIR/ReShade.ini" ]; then
      cp ${reshade-ini} "$GAME_DIR/ReShade.ini"
      chmod u+w "$GAME_DIR/ReShade.ini"
      echo "  fresh template"
    else
      echo "  exists; will be patched"
    fi

    ${patch-reshade-ini}/bin/patch-reshade-ini

    echo ""
    echo "=== Done! ==="
    echo ""
    echo "Set Steam launch options for DBD to include:"
    echo ""
    echo "  WINEDLLOVERRIDES=\"dxgi=n,b\" %command% -dx11"
    echo ""
    echo "Press your overlay key in-game to open the ReShade menu, then"
    echo "select a preset from the dropdown at the top of the overlay."
  '';

  uninstall-reshade-dbd = pkgs.writeShellScriptBin "uninstall-reshade-dbd" ''
    set -euo pipefail
    GAME_DIR="${cfg.gamePath}"

    echo "Removing ReShade from DBD..."
    rm -f  "$GAME_DIR/dxgi.dll"
    rm -f  "$GAME_DIR/ReShade.ini"
    rm -f  "$GAME_DIR/ReShade.log"
    rm -rf "$GAME_DIR/reshade-shaders"
    rm -rf "$GAME_DIR/reshade-presets"
    echo "Done. Remember to remove WINEDLLOVERRIDES from launch options."
  '';

in
{
  options.programs.dbd.reshade = {
    enable = lib.mkEnableOption "ReShade installer for Dead by Daylight";

    gamePath = lib.mkOption {
      type = lib.types.str;
      default = "$HOME/.local/share/Steam/steamapps/common/Dead by Daylight/DeadByDaylight/Binaries/Win64";
      description = ''
        Path to DBD's Win64 binaries directory (where the game executable
        lives). Shell expansion is applied at install/uninstall time, so
        $HOME is fine.
      '';
    };

    settings = lib.mkOption {
      type = lib.types.attrsOf (lib.types.attrsOf scalarType);
      default = { };
      description = ''
        Custom ReShade.ini settings, merged on top of the module's
        defaults via `lib.recursiveUpdate`. Two-level attrset:
        section -> key -> value.

        Module defaults set up search paths, sensible overlay settings,
        and `KeyOverlay = "115,0,0,0"` (F4). Override any of those or
        add new sections/keys via this option.

        On every `home-manager switch` a patcher merges these settings
        into the existing `ReShade.ini` (preserving keys you didn't
        declare — e.g. anything you tweaked via the in-overlay menu).
      '';
      example = lib.literalExpression ''
        {
          INPUT.KeyOverlay = "45,0,0,0";    # Insert
          OVERLAY.ShowFPS = 0;
          OVERLAY.ShowClock = 1;
        }
      '';
    };
  };

  config = lib.mkIf cfg.enable {
    home.packages = [
      install-reshade-dbd
      uninstall-reshade-dbd
      patch-reshade-ini
    ];

    # Re-apply declared ReShade settings on every switch. No-op if
    # ReShade isn't installed yet (the patcher prints a hint and exits 0).
    home.activation.patchReshadeIni = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      $DRY_RUN_CMD ${patch-reshade-ini}/bin/patch-reshade-ini || true
    '';
  };
}
