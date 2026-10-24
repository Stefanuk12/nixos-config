{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  libusb1,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "psvr2-toolkit-driver";
  version = "1.0.0-experimental-1";

  src = fetchurl {
    url = "https://github.com/BnuuySolutions/PSVR2Toolkit/releases/download/v${finalAttrs.version}/PSVR2TK-win64-Ignition.zip";
    hash = "sha256-1MpEkKHUGWqROwbKzHXh3r+TtN618gaQBJ2wc2yH4UQ=";
  };

  nativeBuildInputs = [
    unzip
    autoPatchelfHook
  ];

  # libcrossipc.dll and libusb-1.0.dll are winelib ELF modules, not PE; the latter is the
  # upstream libusb-1.0-winedll bridge onto the host's libusb.
  buildInputs = [
    stdenv.cc.cc.lib
    libusb1
  ];

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
    install -Dm644 -t $out/lib/psvr2-toolkit/win64 \
      driver_playstation_vr2.dll psvr2_toolkit_capi.dll libcrossipc.dll libusb-1.0.dll \
      libcrossipc.so libpsvr2_toolkit_capi.so
    runHook postInstall
  '';

  meta = {
    description = "PSVR2Toolkit SteamVR driver, Ignition (Linux) build";
    homepage = "https://github.com/BnuuySolutions/PSVR2Toolkit";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
  };
})
