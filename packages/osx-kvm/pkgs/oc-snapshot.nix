# OC Snapshot — corpnewt's stdlib-only CLI port of ProperTree's
# snapshot reconciler. Build-time pass over the staged EFI tree to
# align config.plist's ACPI.Add / Kernel.Add / UEFI.Drivers / Misc.Tools
# with what's actually on disk; also fixes kext load order via
# OSBundleLibraries dependency walk.
#
# Bundled snapshot.plist tops out at OC 0.8.4 — mk-image.nix passes
# `-v latest` to side-step the OpenCore.efi MD5 auto-detect lookup
# (never populated for OC 1.0.x).

{ fetchFromGitHub, writeShellScriptBin, python3 }:

let
  src = fetchFromGitHub {
    owner = "corpnewt";
    repo  = "OCSnapshot";
    rev   = "c729337c92d38144e062119515ba36a4e9ccaac9";
    sha256 = "sha256-l0DFC3DvaKqiG9Q72701qIQgkZ+EVhXLPOuTFyFhDyE=";
  };
in
writeShellScriptBin "oc-snapshot" ''
  exec ${python3}/bin/python3 ${src}/OCSnapshot.py "$@"
''
