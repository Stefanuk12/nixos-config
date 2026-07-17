# Builder for Acidanthera kexts (Lilu plugins, VirtualSMC, …); each release zip ships the bundle at the root, or under `Kexts/` for multi-kext releases (VirtualSMC + SMC plugins).

{ fetchzip, runCommand }:

{ name
, version
, sha256
, bundleName ? "${name}.kext"
, subdir    ? ""
}:

let
  src = fetchzip {
    url = "https://github.com/acidanthera/${name}/releases/download/${version}/${name}-${version}-RELEASE.zip";
    inherit sha256;
    stripRoot = false;
  };
  relPath = if subdir == "" then bundleName else "${subdir}/${bundleName}";
in
runCommand "${name}-${version}" { } ''
  cp -r ${src}/${relPath} $out
''
