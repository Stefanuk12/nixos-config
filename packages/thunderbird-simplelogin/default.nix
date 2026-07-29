# SimpleLogin alias manager for Thunderbird, built from ./src into an unsigned XPI.
# The share/mozilla/extensions/<app-id>/ layout is the only shape home-manager's
# `programs.thunderbird.profiles.<n>.extensions` picks up; a bare XPI at $out root is ignored.
#
# Deliberately manifest v2. Thunderbird primes only a fixed set of events to wake a suspended MV3
# event page, and runtime.onMessage is not one of them, so once the background page idled out every
# panel opened to "the background page did not answer". MV2 also keeps browser.contacts and
# browser.mailingLists, which are max_manifest_version 2 and simply undefined under MV3, and grants
# the SimpleLogin host permission at install instead of leaving it opt-in.
{ lib, stdenvNoCC, runCommandLocal, writeShellApplication, nodejs, zip, rbw, jq }:

let
  manifest = lib.importJSON ./src/manifest.json;

  # The XPI filename must equal this, or Thunderbird refuses the install with an id mismatch.
  extensionId = manifest.browser_specific_settings.gecko.id;

  thunderbirdAppId = "{ec8030f7-c20a-464f-9b0e-13a3a9e97384}";
in
stdenvNoCC.mkDerivation {
  pname = "thunderbird-simplelogin-aliases";
  inherit (manifest) version;

  src = ./src;

  nativeBuildInputs = [ zip ];

  dontConfigure = true;

  buildPhase = ''
    runHook preBuild

    # Deterministic XPI: clamped mtimes, sorted entries, no platform extra-fields.
    find . -exec touch -h -d "@$SOURCE_DATE_EPOCH" {} +
    find . -type f | sort | zip -q -X -9 -@ ../extension.xpi

    runHook postBuild
  '';

  installPhase = ''
    runHook preInstall

    dir="$out/share/mozilla/extensions/${thunderbirdAppId}"
    mkdir -p "$dir"
    cp ../extension.xpi "$dir/${extensionId}.xpi"

    runHook postInstall
  '';

  passthru = {
    inherit extensionId;

    # Hands the API key to the add-on via managed storage, so it never lives in the Thunderbird
    # profile. A command rather than a login service: rbw needs an unlocked agent, and a unit
    # firing before the unlock fails silently.
    keySync = writeShellApplication {
      name = "simplelogin-key-sync";
      runtimeInputs = [ rbw jq ];
      text = ''
        entry="''${1:-SimpleLogin API key}"
        id="${extensionId}"

        key="$(rbw get "$entry")"
        if [ -z "$key" ]; then
          echo "simplelogin-key-sync: rbw returned nothing for '$entry'" >&2
          exit 1
        fi

        # Thunderbird's per-user managed-storage dir is undocumented: some builds inherit
        # Firefox's ~/.mozilla path, others use their own. Write both.
        for dir in "$HOME/.mozilla/managed-storage" "$HOME/.thunderbird/managed-storage"; do
          mkdir -p "$dir"
          jq -n --arg id "$id" --arg key "$key" '{
            name: $id,
            description: "SimpleLogin API key for the Thunderbird alias add-on",
            type: "storage",
            data: { apiKey: $key }
          }' > "$dir/$id.json.tmp"
          chmod 600 "$dir/$id.json.tmp"
          mv "$dir/$id.json.tmp" "$dir/$id.json"
        done

        echo "simplelogin-key-sync: key written. Restart Thunderbird to pick it up."
      '';
    };

    # nix build .#thunderbird-simplelogin.tests.<name> — pure logic only; anything touching the
    # Thunderbird or SimpleLogin APIs needs a real client and account. The env vars point at the
    # sources because each file lands in its own store path.
    tests = {
      classify = runCommandLocal "thunderbird-simplelogin-classify-tests" {
        CLASSIFY_JS = ./src/lib/classify.js;
      } ''
        ${nodejs}/bin/node ${./tests/classify.test.js}
        touch $out
      '';

      messages = runCommandLocal "thunderbird-simplelogin-messages-tests" {
        SRC_DIR = ./src;
      } ''
        ${nodejs}/bin/node ${./tests/messages.test.js}
        touch $out
      '';
    };
  };

  meta = {
    description = "Thunderbird add-on to browse SimpleLogin aliases and create them from the compose From field";
    platforms = lib.platforms.all;
    license = lib.licenses.mit;
  };
}
