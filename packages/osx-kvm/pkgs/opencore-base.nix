# OpenCore artefacts pulled from a single upstream release.
#
# `mkEfi { drivers = [...]; }` builds an EFI/{BOOT,OC} tree shipping
# exactly the listed driver basenames, resolved against the OpenCorePkg
# release OR OcBinaryData. mk-config-plist.nix mirrors the same list
# into UEFI.Drivers, so EFI/OC/Drivers/ and the plist can never drift.
#
# `ocvalidate` is the matching-version checker. A version-mismatched
# checker silently misses issues, so it's pinned in lockstep here.
#
# Source toggle:
#   source = "opencore"     (default) — vanilla acidanthera/OpenCorePkg.
#   source = "darwinOCPkg"            — royalgraphx/DarwinOCPkg, a
#     curated QEMU/KVM repackaging of an OpenCorePkg release. Ships
#     OpenCore.efi (DEBUG), BOOTx64.efi and a pre-selected Drivers/
#     set incl. OpenHfsPlus.efi. Tools/ and Resources/ are empty
#     placeholders, so we still source those from the matching
#     upstream release + OcBinaryData. AudioDxe.efi isn't in
#     DarwinOCPkg's Drivers/ either; the resolver falls through.
#
# Opt in per scope with `self.opencore.override { source = "..."; }`.

{ lib, fetchzip, runCommand
, source ? "opencore"
}:

assert lib.elem source [ "opencore" "darwinOCPkg" ];

let
  # Each source pins its own ocVersion + matching release sha so that
  # ocvalidate, Tools/ and the OpenCorePkg fallback stay in lockstep
  # with whatever the chosen variant derives from. DarwinOCPkg's
  # `version` file ("Derived from OpenCorePkg X.Y.Z") is the source
  # of truth — bump in lockstep with darwinOcRev below.
  pinned = {
    opencore = {
      ocVersion       = "1.0.7";
      ocReleaseSha256 = "1jhi8nnab2rvg8pyawn9cxg8j867422xk1xmvzzfb09yn71gxfm8";
    };
    darwinOCPkg = {
      ocVersion       = "1.0.4";
      ocReleaseSha256 = lib.fakeSha256;  # first build prints real hash
    };
  }.${source};

  inherit (pinned) ocVersion;

  ocRelease = fetchzip {
    url = "https://github.com/acidanthera/OpenCorePkg/releases/download/${ocVersion}/OpenCore-${ocVersion}-RELEASE.zip";
    sha256 = pinned.ocReleaseSha256;
    stripRoot = false;
  };

  # OpenCanopy GUI assets + Apple's HFS+ driver — not in the OpenCorePkg
  # release zip, kept in a separate submodule.
  ocBinaryData = fetchzip {
    url = "https://github.com/acidanthera/OcBinaryData/archive/e74e533d8f89c1d5014cfb47c185502bf415741f.tar.gz";
    sha256 = "1dj3mzcbch8m6h88w872bp5anjv95sdz7x8fpcax1n8qkl381407";
  };

  # DarwinOCPkg — royalgraphx's curated repackaging. Pinned by commit;
  # bump together with pinned.darwinOCPkg.ocVersion above. Only fetched
  # when source = "darwinOCPkg", so the fakeSha256 placeholder is inert
  # for the default opencore source.
  darwinOcRev = "82a28361b61d4f664fb6e4f34789abce22bc3088";  # main @ 2025-06-03
  darwinOcRelease = fetchzip {
    url = "https://github.com/royalgraphx/DarwinOCPkg/archive/${darwinOcRev}.tar.gz";
    sha256 = lib.fakeSha256;  # first build prints real hash
  };

  # Resolution order for OpenCore.efi/BOOTx64.efi/Drivers. The
  # OpenCorePkg release is always queried as a second-tier source
  # (e.g. AudioDxe.efi isn't in DarwinOCPkg's curated Drivers/).
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

      # OpenCore.efi + BOOTx64.efi: primary source first, fall back to
      # the matched OpenCorePkg release. Identical paths in both trees.
      for f in BOOT/BOOTx64.efi OC/OpenCore.efi; do
        if   [ -e "${primaryEfi}/$f"  ]; then cp "${primaryEfi}/$f"  "$out/$f"
        elif [ -e "${fallbackEfi}/$f" ]; then cp "${fallbackEfi}/$f" "$out/$f"
        else echo "opencore-base: '$f' not in primary or fallback EFI tree" >&2; exit 1
        fi
      done

      # Driver basenames: primary → OpenCorePkg release → OcBinaryData.
      # An unresolved name fails the build (silent skip = boot-time mystery).
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

      # Tools and Resources always come from the matched upstream pair —
      # DarwinOCPkg ships only .gitkeep in those directories.
      cp ${ocRelease}/X64/EFI/OC/Tools/OpenShell.efi   $out/OC/Tools/Shell.efi
      cp ${ocRelease}/X64/EFI/OC/Tools/ResetSystem.efi $out/OC/Tools/
      cp -r ${ocBinaryData}/Resources/. $out/OC/Resources/
    '';

  # Static x86_64 ELF — no patchelf needed.
  ocvalidate = runCommand "ocvalidate-${ocVersion}" { } ''
    install -Dm755 ${ocRelease}/Utilities/ocvalidate/ocvalidate.linux \
      $out/bin/ocvalidate
  '';

  # DarwinOCPkg ships its own Sample.plist (the QEMU-targeted variant
  # documented in royalgraphx/DarwinKVM); upstream lives at the same
  # path inside the OpenCorePkg release zip.
  samplePlist =
    if source == "darwinOCPkg"
    then "${darwinOcRelease}/Docs/Sample.plist"
    else "${ocRelease}/Docs/Sample.plist";
in
{
  inherit ocVersion mkEfi defaultDrivers ocvalidate samplePlist;
  efi = mkEfi { };
}
