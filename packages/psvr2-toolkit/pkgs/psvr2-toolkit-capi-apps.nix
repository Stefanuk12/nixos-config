{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "psvr2-toolkit-capi-apps";
  version = "1.0.0-experimental-1";

  src = fetchurl {
    url = "https://github.com/BnuuySolutions/PSVR2Toolkit/releases/download/v${finalAttrs.version}/CAPIApps-Linux.zip";
    hash = "sha256-UiAr+uCDyvK1/Sp1xqKOFO0CwJnyg5LRcKvoYVd4u6A=";
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

  # psvr2_toolkit_capi_test (and its bundled SDL3) want GLIBC_2.43; add them back once nixpkgs
  # ships glibc 2.43.
  installPhase = ''
    runHook preInstall
    install -Dm644 -t $out/lib/psvr2-toolkit-capi libpsvr2_toolkit_capi_loader.so
    install -Dm755 -t $out/lib/psvr2-toolkit-capi psvr2_toolkit_legacy_ipc_server
    mkdir -p $out/bin
    ln -s ../lib/psvr2-toolkit-capi/psvr2_toolkit_legacy_ipc_server $out/bin/psvr2-toolkit-legacy-ipc-server
    runHook postInstall
  '';

  meta = {
    description = "PSVR2Toolkit legacy IPC server, for apps built against the pre-experimental protocol (VRCFT module etc.)";
    homepage = "https://github.com/BnuuySolutions/PSVR2Toolkit";
    license = lib.licenses.mit;
    sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
    platforms = [ "x86_64-linux" ];
    mainProgram = "psvr2-toolkit-legacy-ipc-server";
  };
})
