# OC Snapshot — corpnewt's CLI port of ProperTree's snapshot reconciler.
# Aligns config.plist's ACPI.Add/Kernel.Add/UEFI.Drivers/Misc.Tools with the
# staged EFI tree and fixes kext load order via OSBundleLibraries walk.
#
# Bundled snapshot.plist tops out at OC 0.8.4, so mk-image.nix passes
# `-v latest` to skip the OpenCore.efi MD5 auto-detect (absent for OC 1.0.x).

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
