# Unpacked MV3 extension that restores automatic page translation, which ungoogled strips out of
# helium. Detects a foreign-language page on load and translates it through translate.googleapis.com
# (the free endpoint, no API key), so pages leave the browser's de-googled path by design.
# Upstream ships no LICENSE file, hence no meta.license.
{
  lib,
  stdenvNoCC,
  fetchFromGitHub,
}:

stdenvNoCC.mkDerivation {
  pname = "helium-autotranslate";
  version = "1.0-unstable-2026-07-27";

  src = fetchFromGitHub {
    owner = "HadiSoufi";
    repo = "autotranslate";
    rev = "465efb57a2acbe9ab3a52ef306e9d81fca1b95ad";
    hash = "sha256-i+b/dgZ5P6QFrpzEDx5IrLvqTCxsW3G6VxP2gZ38tLc=";
  };

  dontConfigure = true;
  dontBuild = true;

  # Google now answers translate_a/single with a 429 "Sorry..." interstitial for client=gtx, which
  # is the client upstream hardcodes, so every translation silently no-ops. client=dict-chrome-ex
  # is what Chrome's own translate extension sends; same response shape, still served. Drop this
  # if upstream switches clients.
  postPatch = ''
    substituteInPlace src/background.js \
      --replace-fail "client: 'gtx'" "client: 'dict-chrome-ex'"
  '';

  installPhase = ''
    runHook preInstall
    mkdir -p $out
    cp -r manifest.json icons src $out/
    runHook postInstall
  '';

  meta = {
    description = "Automatic page translation for helium and other ungoogled-chromium browsers";
    homepage = "https://github.com/HadiSoufi/autotranslate";
    platforms = lib.platforms.all;
  };
}
