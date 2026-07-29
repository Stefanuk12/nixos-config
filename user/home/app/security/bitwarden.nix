{ pkgs, lib, ... }:

let
  # Serves the rbw master password from a sops-decrypted file so `rbw unlock` never prompts.
  # Refuses register prompts (client__id/client__secret) — use pinentry-qt for those.
  pinentrySmart = pkgs.writeShellScriptBin "pinentry-smart" ''
    pw_file=/run/secrets/bw/master_password
    state="master"
    echo "OK Greetings"
    while IFS= read -r line; do
      cmd="''${line%% *}"
      rest="''${line#* }"
      case "$cmd" in
        SETDESC|SETPROMPT|SETKEYINFO)
          case "$rest" in
            *client__id*|*client__secret*) state="fallback" ;;
          esac
          echo "OK"
          ;;
        GETPIN)
          if [ "$state" = "fallback" ] || [ ! -r "$pw_file" ]; then
            echo "ERR 83886179 pinentry-smart only serves the master password; use pinentry-qt for this prompt"
            exit 1
          fi
          printf 'D %s\nOK\n' "$(cat "$pw_file")"
          state="master"
          ;;
        BYE) echo "OK"; exit 0 ;;
        *)   echo "OK" ;;
      esac
    done
  '';

  # WebAuthn 2FA from doy/rbw PR #334, unmerged as of 1.15.0. Its USB backend (fido-hid-rs) links
  # libudev, hence pkg-config + udev. Crates vendor from the PR's Cargo.lock, so no cargoHash.
  rbw = pkgs.rbw.overrideAttrs (old: {
    version = "1.15.0-webauthn-pr334";
    src = pkgs.fetchFromGitHub {
      owner = "aokellermann";
      repo = "rbw";
      rev = "02471b8a798e8021a10ff6799f7e997a71a4070a";
      hash = "sha256-pXqOjQq8f7cu8zo+Lbf5DOUMCHYc+Lv4PV7uG/m7ZSo=";
    };
    cargoDeps = pkgs.rustPlatform.importCargoLock {
      lockFile = ./rbw-webauthn-Cargo.lock;
    };
    buildFeatures = (old.buildFeatures or [ ]) ++ [ "webauthn" ];
    nativeBuildInputs = (old.nativeBuildInputs or [ ]) ++ [ pkgs.pkg-config ];
    buildInputs = (old.buildInputs or [ ]) ++ [ pkgs.udev ];
  });
in
{
  home.packages = [
    rbw
    pkgs.rofi-rbw
    pkgs.pinentry-qt
    pinentrySmart
  ];

  # Plain F-keys: Hyprland doesn't grab them, rofi's defaults don't use them, and they can't clash
  # with typed search input.
  xdg.configFile."rofi-rbw.rc".text = ''
    keybindings = F1:type:username:tab:password,F2:type:username,F3:type:password,F4:type:totp,F5:copy:password,F6:copy:username,F7:copy:totp,F8::menu,F9:sync
    menu-keybindings = F2:type,F5:copy
  '';

  home.activation.rbw-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -r /run/secrets/bw/email ]; then
      email=$(cat /run/secrets/bw/email)
      run ${rbw}/bin/rbw config set email "$email"
    else
      echo "rbw-config: /run/secrets/bw/email not readable, skipping email" >&2
    fi
    run ${rbw}/bin/rbw config set base_url https://vault.bitwarden.com
    run ${rbw}/bin/rbw config set pinentry ${pinentrySmart}/bin/pinentry-smart
  '';
}
