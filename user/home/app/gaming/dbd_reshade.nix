{ pkgs, ... }:

let
  reshade-version = "6.3.3";

  reshade-bin = pkgs.fetchurl {
    url = "https://reshade.me/downloads/ReShade_Setup_${reshade-version}.exe";
    hash = "sha256-TdvcAyqRS1Z92PjKpZpbeFwytJDAujxQQPVEgkyYCmw=";
  };

  # Standard ReShade shader collection (slim branch has the popular ones)
  reshade-shaders = pkgs.fetchFromGitHub {
    owner = "crosire";
    repo = "reshade-shaders";
    rev = "6db142b4b1a05c764222e5b0bd9a644b7ccfe1dc";
    hash = "sha256-WqT4eU8ZlGwKEgUEGlivz+35GprKX4goBeLnp9D5lTY=";
  };

  # Prod80 color effects (used by many presets like Elevated)
  prod80-shaders = pkgs.fetchFromGitHub {
    owner = "prod80";
    repo = "prod80-ReShade-Repository";
    rev = "1c2ed5b093b03c558bfa6aea45c2087052e99554";
    hash = "sha256-EM9WxpbN0tUB9yjZFwWtY1l8um7jvMfC2eenEl2amF8=";
  };

  # DBDReshade preset collection by Joolace (most popular)
  dbd-presets = pkgs.fetchFromGitHub {
    owner = "Joolace";
    repo = "dbd-reshade";
    rev = "5e84695c1fbf2402390feb3d96935e79ceff7157";
    hash = "sha256-7Qxbh4IsvdJj7e/lyJww1R3PL/1dCW3TVwLVrxZ69/g=";
  };

  # STEAXS Filter Pack (DBD-specific presets)
  steaxs-presets = pkgs.fetchFromGitHub {
    owner = "steaxss";
    repo = "STEAXS-FILTER-PACK";
    rev = "5beb3b861d30b25047bd534cf7178d4222994b6f";
    hash = "sha256-NXirUblL5gs7hN+0ZpYo7C+ItUVgNDK25+nSj1eMaN8=";
  };

  dbd-path = "$HOME/.local/share/Steam/steamapps/common/Dead by Daylight/DeadByDaylight/Binaries/Win64";

  # Keybind: keycode,ctrl,shift,alt (0 = off, 1 = on)
  #   36 = Home | 45 = Insert | 119 = Delete | 118 = Page Down
  #   112 = F1 | 113 = F2 | 123 = F12
  #   Example: "112,0,1,0" = Shift+F1
  overlayKey = "115,0,0,0"; # F4

  install-reshade-dbd = pkgs.writeShellScriptBin "install-reshade-dbd" ''
    set -euo pipefail
    GAME_DIR="${dbd-path}"

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

    # Prod80 color effects
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
    ${pkgs.p7zip}/bin/7z e -y -o/tmp/reshade-extract ${reshade-bin} "ReShade64.dll" > /dev/null 2>&1 || true

    if [ -f /tmp/reshade-extract/ReShade64.dll ]; then
      cp /tmp/reshade-extract/ReShade64.dll "$GAME_DIR/dxgi.dll"
      rm -rf /tmp/reshade-extract
      echo "  ReShade64.dll -> dxgi.dll"
    else
      echo "ERROR: Failed to extract ReShade64.dll"
      echo "You may need to download it manually from https://reshade.me"
      exit 1
    fi

    # --- Config ---
    echo "[4/4] Writing ReShade.ini..."
    cat > "$GAME_DIR/ReShade.ini" << EOF
[GENERAL]
EffectSearchPaths=.\reshade-shaders\Shaders
TextureSearchPaths=.\reshade-shaders\Textures
PresetPath=.\reshade-presets
PresetTransitionDelay=1000
SkipLoadingDisabledEffects=1

[INPUT]
KeyOverlay=${overlayKey}
ForceShortcutModifiers=1
GamepadNavigation=1

[OVERLAY]
TutorialProgress=4
ShowFPS=1
ShowClock=0
EOF

    echo ""
    echo "=== Done! ==="
    echo ""
    echo "Set these Steam launch options for DBD:"
    echo ""
    echo "  WINEDLLOVERRIDES=\"dxgi=n,b\" DRI_PRIME=1 %command% -dx11"
    echo ""
    echo "Press Insert (or your configured key) in-game to open the ReShade menu."
    echo "Select a preset from the dropdown at the top of the overlay."
  '';

  uninstall-reshade-dbd = pkgs.writeShellScriptBin "uninstall-reshade-dbd" ''
    set -euo pipefail
    GAME_DIR="${dbd-path}"

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
  home.packages = [
    install-reshade-dbd
    uninstall-reshade-dbd
  ];
}
