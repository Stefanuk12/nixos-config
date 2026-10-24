{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  pkg-config,
  libusb1,
}:

stdenv.mkDerivation (finalAttrs: {
  pname = "psvr2-updater";
  version = "1.0";

  src = fetchFromGitHub {
    owner = "RealSupremium";
    repo = "PSVR2Updater";
    tag = "v${finalAttrs.version}";
    hash = "sha256-vz5AIqW43LnL1l56gMrhhF1fFYwZVeDdJx32lSgs53o=";
  };

  nativeBuildInputs = [
    cmake
    pkg-config
  ];

  buildInputs = [ libusb1 ];

  installPhase = ''
    runHook preInstall
    install -Dm755 bin/PSVR2Updater $out/bin/psvr2-updater
    runHook postInstall
  '';

  meta = {
    description = "Reads PSVR2 headset firmware info and flashes .cup firmware files over USB";
    homepage = "https://github.com/RealSupremium/PSVR2Updater";
    license = lib.licenses.unfree;
    platforms = lib.platforms.linux;
    mainProgram = "psvr2-updater";
  };
})
