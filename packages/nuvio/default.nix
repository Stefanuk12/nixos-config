{
  lib,
  appimageTools,
  fetchurl,
}:
let
  pname = "nuvio";
  version = "0.1.27-alpha";

  src = fetchurl {
    url = "https://github.com/NuvioMedia/NuvioDesktop/releases/download/${version}/Nuvio-Linux-x86_64-${version}.AppImage";
    hash = "sha256-IcgnAGXs6MNoJ++cR2WhkqFFY3yVDx/UGOTzr3VjLKI=";
  };

  contents = appimageTools.extract { inherit pname version src; };
in
appimageTools.wrapType2 {
  inherit pname version src;

  # The player's JNI bridge links libmpv + webkit2gtk-4.1 without bundling them. The
  # composeMediaPlayer fallback is GStreamer, and the FHS defaults only carry base + ugly.
  extraPkgs =
    pkgs:
    [
      pkgs.mpv-unwrapped
      pkgs.webkitgtk_4_1
    ]
    ++ (with pkgs.gst_all_1; [
      gst-plugins-good
      gst-plugins-bad
      gst-libav
    ]);

  extraInstallCommands = ''
    install -Dm444 ${contents}/Nuvio.desktop $out/share/applications/nuvio.desktop
    substituteInPlace $out/share/applications/nuvio.desktop \
      --replace-fail 'Exec=AppRun' 'Exec=nuvio' \
      --replace-fail 'Icon=Nuvio' 'Icon=nuvio'
    install -Dm444 ${contents}/Nuvio.png $out/share/icons/hicolor/256x256/apps/nuvio.png
  '';

  meta = {
    description = "Stremio-addon media player";
    homepage = "https://github.com/NuvioMedia/NuvioDesktop";
    license = lib.licenses.gpl3Only;
    mainProgram = "nuvio";
    platforms = [ "x86_64-linux" ];
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
  };
}
