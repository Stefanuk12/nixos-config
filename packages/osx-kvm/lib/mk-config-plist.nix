# Generates config.plist by mutating a base plist (default:
# OpenCorePkg's Sample.plist, fetched via opencore-base.nix).
#
# Inputs:
#   profile          — { smbios?, bootArgs?, csrActiveConfig?, kexts?,
#                        kextBlocks?, acpi? }
#   basePlist        — path to plist file used as the starting point
#   extraKexts/Blocks/Acpi — appended to the profile's lists
#   drivers          — null leaves Sample.plist's UEFI.Drivers untouched
#   plistOverrides   — Nix attrset deep-merged onto the parsed plist
#                      after structured ops; mirrors the plist tree.
#                      Non-string scalars use the tagged form expected
#                      by render-plist.py:
#                        { _type = "data"; value = "<base64>"; }
#                        { _type = "date"; value = "<iso8601>"; }

{ lib, runCommand, python3, writeText, opencore }:

{ profile
, basePlist       ? opencore.samplePlist
, extraKexts      ? [ ]
, extraKextBlocks ? [ ]
, extraAcpi       ? [ ]
, drivers         ? null
, plistOverrides  ? { }
}:

let
  allKexts      = (profile.kexts      or [ ]) ++ extraKexts;
  allKextBlocks = (profile.kextBlocks or [ ]) ++ extraKextBlocks;
  allAcpi       = (profile.acpi       or [ ]) ++ extraAcpi;

  kextsJson = map (k: {
    bundlePath     = k.bundlePath;
    executablePath = k.executablePath or "";
    minKernel      = k.minKernel or "";
    maxKernel      = k.maxKernel or "";
    comment        = k.comment or k.bundlePath;
  }) allKexts;

  blocksJson = map (b: {
    identifier = b.identifier;
    enabled    = b.enabled or false;
    strategy   = b.strategy or "Disable";
    minKernel  = b.minKernel or "";
    maxKernel  = b.maxKernel or "";
    comment    = b.comment or "";
  }) allKextBlocks;

  acpiJson = map (a: {
    name    = a.name;
    comment = a.comment or a.name;
  }) allAcpi;

  structured = lib.filterAttrs (_: v: v != null) {
    smbios          = profile.smbios or null;
    bootArgs        = profile.bootArgs or null;
    csrActiveConfig = profile.csrActiveConfig or null;
    kexts           = if allKexts != [ ] then kextsJson else null;
    kextBlocks      = if allKextBlocks != [ ] then blocksJson else null;
    acpi            = if allAcpi != [ ] then acpiJson else null;
    inherit drivers;
  };

  structuredJson = writeText "config-structured.json" (builtins.toJSON structured);
  overridesJson  = writeText "config-overrides.json"  (builtins.toJSON plistOverrides);
in

runCommand "config.plist" { nativeBuildInputs = [ python3 ]; } ''
  python3 ${./render-plist.py} \
    ${basePlist} ${structuredJson} ${overridesJson} $out
''
