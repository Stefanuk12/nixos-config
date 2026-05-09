# BaseSystem fetcher — wraps OSX-KVM's fetch-macOS-v2.py.
# Apple's recovery URLs aren't pin-able, so the actual download runs at
# user-time, not build-time. Default target dir: $OSX_KVM_DIR or
# ~/.local/share/osx-kvm.
#
#   nix run .#fetch-basesystem            # interactive picker
#   nix run .#fetch-basesystem-sonoma     # non-interactive, fixed version
#
# `mkFetcher` is exposed for callers wanting a custom shortname or to
# bake additional default args.

{ lib, fetchurl, writeShellApplication, python3, qemu-utils }:

let
  fetcherSrc = fetchurl {
    url = "https://raw.githubusercontent.com/kholia/OSX-KVM/4c378a4b5e0b219783683012bec680325eb40719/fetch-macOS-v2.py";
    sha256 = "1wymbc6hj25hw8mp0km7nypr7vqmmlazaql034r5spr6plk6vb1r";
  };

  # Matches the --shortname options accepted by fetch-macOS-v2.py.
  # When set, the upstream script picks board-id/MLB from boards.json
  # and skips the interactive product picker entirely.
  shortnames = [
    "high-sierra" "mojave" "catalina" "big-sur" "monterey"
    "ventura" "sonoma" "sequoia" "tahoe"
  ];

  mkFetcher = { shortname ? null }:
    let
      suffix      = lib.optionalString (shortname != null) "-${shortname}";
      defaultArgs = lib.optionalString (shortname != null) "--shortname ${shortname}";
      label       = if shortname == null then "" else " (${shortname})";
    in
    writeShellApplication {
      name = "osx-kvm-fetch-basesystem${suffix}";
      runtimeInputs = [ python3 qemu-utils ];
      text = ''
        target_dir="''${OSX_KVM_DIR:-$HOME/.local/share/osx-kvm}"
        while [ $# -gt 0 ]; do
          case "$1" in
            --target-dir) target_dir="$2"; shift 2 ;;
            *) break ;;
          esac
        done
        mkdir -p "$target_dir"
        cd "$target_dir"

        echo "Fetching macOS recovery${label} into $target_dir ..."
        # Defaults come first; user args last so argparse last-wins lets
        # callers override (e.g. swap shortname, pass --board-id).
        python3 ${fetcherSrc} ${defaultArgs} "$@"

        if [ -f BaseSystem.dmg ] && [ ! -f BaseSystem.img ]; then
          echo "Converting BaseSystem.dmg → BaseSystem.img ..."
          qemu-img convert BaseSystem.dmg -O raw BaseSystem.img
        fi

        if [ ! -f mac_hdd_ng.img ]; then
          echo "Creating empty mac_hdd_ng.img (128 GB sparse) ..."
          qemu-img create -f qcow2 mac_hdd_ng.img 128G
        fi

        echo "Done. Files in $target_dir:"
        ls -lh "$target_dir"
      '';
    };
in
{
  inherit mkFetcher;
  default = mkFetcher { };
} // lib.genAttrs shortnames (v: mkFetcher { shortname = v; })
