{ pkgs, ... }:

let
  wine = pkgs.wineWow64Packages.staging;
  wineasio = pkgs.wineasio;

  # The fake wineasio64.dll exports itself as "wineasio.dll", so Wine looks for
  # wineasio.dll.so; nixpkgs installs the unix half as wineasio64.dll.so. It then
  # dlopens libjack.so.0 by bare name, hence the pipewire-jack LD_LIBRARY_PATH.
  wineasioDlls = pkgs.runCommand "wineasio-dlls" { } ''
    mkdir -p $out/x86_64-unix
    ln -s ${wineasio}/lib/wine/x86_64-unix/wineasio64.dll.so $out/x86_64-unix/wineasio.dll.so
  '';

  # Dedicated 64-bit prefix + wineasio bootstrap on first run. Actually installing FL Studio
  # (or any VSTs) into it stays a manual, imperative step: `flstudio /path/to/installer.exe`.
  flstudio = pkgs.writeShellApplication {
    name = "flstudio";
    runtimeInputs = [
      wine
      wineasio
      pkgs.winetricks
      pkgs.findutils
    ];
    text = ''
      export WINEPREFIX="''${FLSTUDIO_PREFIX:-$HOME/.local/share/wineprefixes/flstudio}"
      export WINEARCH=win64
      export WINEDLLPATH="${wineasioDlls}''${WINEDLLPATH:+:$WINEDLLPATH}"
      export LD_LIBRARY_PATH="${pkgs.pipewire.jack}/lib''${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
      # wineasio reports jack_get_buffer_size() from Init as a fixed size but copies whatever
      # nframes pipewire later delivers, so the graph quantum must not drift while FL runs.
      export PIPEWIRE_QUANTUM="''${FLSTUDIO_QUANTUM:-1024/48000}"

      if [ ! -d "$WINEPREFIX" ]; then
        echo "Bootstrapping FL Studio wineprefix at $WINEPREFIX..."
        mkdir -p "$WINEPREFIX"
        wineboot --init
        winetricks -q corefonts vcrun2019 dotnet48
        install -Dm644 "${wineasio}/lib/wine/x86_64-windows/wineasio64.dll" \
          "$WINEPREFIX/drive_c/windows/system32/wineasio64.dll"
        wine regsvr32 wineasio64.dll
      fi

      if [ "$#" -gt 0 ]; then
        exec wine "$@"
      fi

      fl64=$(find "$WINEPREFIX/drive_c/Program Files/Image-Line" -iname "FL64.exe" -print -quit)
      if [ -z "$fl64" ]; then
        echo "FL Studio isn't installed yet — run: flstudio /path/to/installer.exe" >&2
        exit 1
      fi
      exec wine "$fl64"
    '';
  };
in
{
  home.packages = [ flstudio ];
}
