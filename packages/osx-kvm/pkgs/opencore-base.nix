# OpenCore artefacts from a single upstream release. `mkEfi { drivers = [...]; }`
# builds an EFI/{BOOT,OC} tree; mk-config-plist.nix mirrors the same list into
# UEFI.Drivers so EFI/OC/Drivers/ and the plist can't drift. `ocvalidate` is
# version-pinned in lockstep since a mismatched checker silently misses issues.
#
# source = "opencore" (default) uses vanilla acidanthera/OpenCorePkg;
# source = "darwinOCPkg" uses royalgraphx's QEMU/KVM repackaging, but its
# Tools/Resources are placeholders and it lacks AudioDxe.efi, so those still
# come from the matching upstream release + OcBinaryData (resolver falls through).
# Opt in per scope with `self.opencore.override { source = "..."; }`.

{ lib, fetchzip, runCommand
, source ? "opencore"
}:

assert lib.elem source [ "opencore" "darwinOCPkg" ];

let
  # Each source pins its own ocVersion + matching sha so ocvalidate, Tools/ and
  # the fallback stay in lockstep. For darwinOCPkg, its `version` file ("Derived
  # from OpenCorePkg X.Y.Z") is the source of truth — bump with darwinOcRev below.
  pinned = {
    opencore = {
      ocVersion       = "1.0.7";
      ocReleaseSha256 = "1jhi8nnab2rvg8pyawn9cxg8j867422xk1xmvzzfb09yn71gxfm8";
    };
    darwinOCPkg = {
      ocVersion       = "1.0.4";
      ocReleaseSha256 = "sha256-B01OlZzEMmpXDguyvADxH5GWjZzFJUKF/QVuHFgQ1CQ=";  # first build prints real hash
    };
  }.${source};

  inherit (pinned) ocVersion;

  ocRelease = fetchzip {
    url = "https://github.com/acidanthera/OpenCorePkg/releases/download/${ocVersion}/OpenCore-${ocVersion}-RELEASE.zip";
    sha256 = pinned.ocReleaseSha256;
    stripRoot = false;
  };

  # OpenCanopy GUI assets + Apple's HFS+ driver — not in the release zip.
  ocBinaryData = fetchzip {
    url = "https://github.com/acidanthera/OcBinaryData/archive/e74e533d8f89c1d5014cfb47c185502bf415741f.tar.gz";
    sha256 = "1dj3mzcbch8m6h88w872bp5anjv95sdz7x8fpcax1n8qkl381407";
  };

  # DarwinOCPkg — pinned by commit; bump with pinned.darwinOCPkg.ocVersion above.
  # Only fetched when source = "darwinOCPkg".
  darwinOcRev = "82a28361b61d4f664fb6e4f34789abce22bc3088";  # main @ 2025-06-03
  darwinOcRelease = fetchzip {
    url = "https://github.com/royalgraphx/DarwinOCPkg/archive/${darwinOcRev}.tar.gz";
    sha256 = "sha256-B01OlZzEMmpXDguyvADxH5GWjZzFJUKF/QVuHFgQ1CQ=";  # first build prints real hash
  };

  # Resolution order for EFI files/Drivers: primary, then OpenCorePkg release
  # as fallback (e.g. AudioDxe.efi isn't in DarwinOCPkg's Drivers/).
  primaryEfi  = if source == "darwinOCPkg"
                then "${darwinOcRelease}/X64/EFI"
                else "${ocRelease}/X64/EFI";
  fallbackEfi = "${ocRelease}/X64/EFI";

  defaultDrivers = [
    "OpenRuntime.efi"
    "OpenCanopy.efi"
    "OpenHfsPlus.efi"
    "AudioDxe.efi"
    "ResetNvramEntry.efi"
  ];

  mkEfi = { drivers ? defaultDrivers }:
    runCommand "opencore-efi-base-${source}-${ocVersion}" { } ''
      mkdir -p $out/BOOT $out/OC/{Drivers,Tools,Kexts,ACPI,Resources}

      # OpenCore.efi + BOOTx64.efi: primary first, then matched OpenCorePkg release.
      for f in BOOT/BOOTx64.efi OC/OpenCore.efi; do
        if   [ -e "${primaryEfi}/$f"  ]; then cp "${primaryEfi}/$f"  "$out/$f"
        elif [ -e "${fallbackEfi}/$f" ]; then cp "${fallbackEfi}/$f" "$out/$f"
        else echo "opencore-base: '$f' not in primary or fallback EFI tree" >&2; exit 1
        fi
      done

      # Driver basenames: primary → OpenCorePkg release → OcBinaryData.
      # Unresolved name fails the build (silent skip = boot-time mystery).
      ${lib.concatMapStringsSep "\n" (d: ''
        if   [ -e "${primaryEfi}/OC/Drivers/${d}" ]; then
          cp "${primaryEfi}/OC/Drivers/${d}" $out/OC/Drivers/
        elif [ -e "${fallbackEfi}/OC/Drivers/${d}" ]; then
          cp "${fallbackEfi}/OC/Drivers/${d}" $out/OC/Drivers/
        elif [ -e "${ocBinaryData}/Drivers/${d}" ]; then
          cp "${ocBinaryData}/Drivers/${d}" $out/OC/Drivers/
        else
          echo "opencore-base: driver '${d}' not in DarwinOCPkg/OpenCorePkg/OcBinaryData" >&2
          exit 1
        fi
      '') drivers}

      # Tools and Resources always come from upstream — DarwinOCPkg ships only
      # .gitkeep in those directories.
      cp ${ocRelease}/X64/EFI/OC/Tools/OpenShell.efi   $out/OC/Tools/Shell.efi
      cp ${ocRelease}/X64/EFI/OC/Tools/ResetSystem.efi $out/OC/Tools/
      cp -r ${ocBinaryData}/Resources/. $out/OC/Resources/
    '';

  # Static x86_64 ELF — no patchelf needed.
  ocvalidate = runCommand "ocvalidate-${ocVersion}" { } ''
    install -Dm755 ${ocRelease}/Utilities/ocvalidate/ocvalidate.linux \
      $out/bin/ocvalidate
  '';

  # DarwinOCPkg ships its own QEMU-targeted Sample.plist; upstream's lives at
  # the same path inside the OpenCorePkg release zip.
  samplePlist =
    if source == "darwinOCPkg"
    then "${darwinOcRelease}/Docs/Sample.plist"
    else "${ocRelease}/Docs/Sample.plist";
in
{
  inherit ocVersion mkEfi defaultDrivers ocvalidate samplePlist;
  efi = mkEfi { };
}
