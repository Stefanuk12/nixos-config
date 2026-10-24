{
  lib,
  monado,
  fetchFromGitLab,
}:

monado.overrideAttrs (prev: {
  pname = "monado-psvr2";
  version = "0-unstable-2026-06-04";

  src = fetchFromGitLab {
    domain = "gitlab.freedesktop.org";
    owner = "Beyley";
    repo = "monado";
    rev = "47f9d39e686d6bbd7dad914b4dbe21f784c41911";
    hash = "sha256-APEA1ivUGTrchePh1XJXycxB9/IRze7ltCPH0qkvAE4=";
  };

  # Both nixpkgs patches are against v25.1.0 and the branch already carries them.
  patches = [ ];

  # option_with_deps would pick it up anyway; explicit so a missing dep fails the build here
  # rather than silently producing a runtime with no PSVR2 support.
  cmakeFlags = prev.cmakeFlags ++ [ (lib.cmakeBool "XRT_BUILD_DRIVER_PSVR2" true) ];

  meta = prev.meta // {
    description = "Monado with the PS VR2 driver (Beyley's psvr2-work-steamvr branch)";
  };
})
