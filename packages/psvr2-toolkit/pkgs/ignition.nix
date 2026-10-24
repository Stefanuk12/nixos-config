{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "ignition";
  version = "1.0.0";

  src = fetchurl {
    url = "https://github.com/BnuuySolutions/Ignition/releases/download/v${finalAttrs.version}/Ignition-Linux-Windows.zip";
    hash = "sha256-YJBjdb3FYlXIrYCod1BCX7BgOf1AEbsqFtMgvuURY8g=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  buildInputs = [ stdenv.cc.cc.lib ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src" -d source
    runHook postUnpack
  '';
  sourceRoot = "source";

  dontConfigure = true;
  dontBuild = true;

  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/lib/ignition libdriver_ignition.so ignition_server.exe ignition_bridge.dll wine_psvr2_hidraw.reg
    install -Dm755 -t $out/lib/ignition proton launch_serverhelper.sh install_ignition.sh driver_install.sh driver_uninstall.sh
    runHook postInstall
  '';

  meta = {
    description = "Runs Windows-only SteamVR drivers on Linux through Wine/Proton";
    homepage = "https://github.com/BnuuySolutions/Ignition";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
})
