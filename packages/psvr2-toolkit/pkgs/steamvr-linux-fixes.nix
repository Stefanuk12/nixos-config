{
  lib,
  stdenv,
  fetchFromGitHub,
  cmake,
  vulkan-headers,
  vulkan-loader,
}:

let
  # funchook downloads its disassembler with FetchContent at configure time.
  distorm = fetchFromGitHub {
    owner = "gdabah";
    repo = "distorm";
    rev = "ed2d3916a83998c9de83924855a6e9ff40f9f17d";
    hash = "sha256-2ftEV3TMS3HT7f96k+Pwt3Mm31fVEXcHpcbbz05jycU=";
  };
in
stdenv.mkDerivation (finalAttrs: {
  pname = "steamvr-linux-fixes";
  version = "0.1.4";

  src = fetchFromGitHub {
    owner = "BnuuySolutions";
    repo = "SteamVRLinuxFixes";
    tag = "v${finalAttrs.version}";
    fetchSubmodules = true;
    hash = "sha256-Zvk7I4df+Y8FsnkNLZ+h3SsdFK9BL35TCJgsSk/G58U=";
  };

  nativeBuildInputs = [ cmake ];

  buildInputs = [
    vulkan-headers
    vulkan-loader
  ];

  # funchook's .S files carry no .note.GNU-stack, so ld marks the layer RWE and glibc 2.41+ then
  # refuses to dlopen it ("cannot enable executable stack"). Nothing in it needs one.
  env.NIX_LDFLAGS = "-z noexecstack";

  cmakeFlags = [
    (lib.cmakeFeature "FETCHCONTENT_SOURCE_DIR_DISTORM" "${distorm}")
    (lib.cmakeBool "FETCHCONTENT_FULLY_DISCONNECTED" true)
    (lib.cmakeBool "FUNCHOOK_BUILD_SHARED" false)
    (lib.cmakeBool "FUNCHOOK_BUILD_TESTS" false)
    (lib.cmakeBool "FUNCHOOK_INSTALL" false)
  ];

  installPhase = ''
    runHook preInstall
    install -Dm755 libsteamvr_linux_fixes.so $out/lib/libsteamvr_linux_fixes.so
    install -Dm644 VkLayer_steamvr_linux_fixes.json $out/share/vulkan/implicit_layer.d/VkLayer_steamvr_linux_fixes.json
    substituteInPlace $out/share/vulkan/implicit_layer.d/VkLayer_steamvr_linux_fixes.json \
      --replace-fail '"./libsteamvr_linux_fixes.so"' '"'"$out"'/lib/libsteamvr_linux_fixes.so"'
    runHook postInstall
  '';

  meta = {
    description = "Vulkan layer patching SteamVR's vrcompositor for wired headsets (refresh rates, present wait, Mesa 26 swapchain)";
    homepage = "https://github.com/BnuuySolutions/SteamVRLinuxFixes";
    license = lib.licenses.mit;
    platforms = [ "x86_64-linux" ];
  };
})
