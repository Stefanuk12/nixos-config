{
  lib,
  stdenv,
  fetchurl,
  unzip,
  makeWrapper,
  steam-run,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "psvr2-unity-setup";
  version = "1.1.0";

  src = fetchurl {
    url = "https://github.com/BnuuySolutions/PSVR2Toolkit.UnitySetup/releases/download/v${finalAttrs.version}/PSVR2Toolkit.UnitySetup-Linux.zip";
    hash = "sha256-XiI3c+ZhX3G5SWOTrp4ddN9DyrKjDmfhobOJ5MyK19o=";
  };

  nativeBuildInputs = [
    unzip
    makeWrapper
  ];

  unpackPhase = ''
    runHook preUnpack
    unzip -q "$src" -d source
    runHook postUnpack
  '';
  sourceRoot = "source";

  dontConfigure = true;
  dontBuild = true;
  # Loads SteamVR's own vrclient.so at runtime, so it has to live in the Steam FHS env anyway.
  dontPatchELF = true;
  dontStrip = true;

  installPhase = ''
    runHook preInstall
    mkdir -p $out/share/psvr2-unity-setup $out/bin
    cp -r . $out/share/psvr2-unity-setup
    chmod 755 $out/share/psvr2-unity-setup/PSVR2Toolkit.UnitySetup.x86_64
    makeWrapper ${lib.getExe steam-run} $out/bin/psvr2-unity-setup \
      --add-flags $out/share/psvr2-unity-setup/PSVR2Toolkit.UnitySetup.x86_64
    runHook postInstall
  '';

  meta = {
    description = "Play area setup, passthrough and eye-tracking calibration for PSVR2 on SteamVR";
    homepage = "https://github.com/BnuuySolutions/PSVR2Toolkit.UnitySetup";
    license = lib.licenses.unfree;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "psvr2-unity-setup";
  };
})
