{ pkgs, lib, ... }:

let
  # Pinentry that serves the rbw master password from a sops-decrypted file
  # so `rbw unlock` / `rofi-rbw` never prompts. Falls back loudly if the file
  # isn't readable, and refuses to serve the master password to a prompt that
  # looks like rbw register (client__id / client__secret) — those one-time
  # interactive ops should temporarily use pinentry-qt instead.
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
in
{
  home.packages = [
    pkgs.rbw
    pkgs.rofi-rbw
    pkgs.pinentry-qt
    pinentrySmart
  ];

  home.activation.rbw-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    if [ -r /run/secrets/bw/email ]; then
      email=$(cat /run/secrets/bw/email)
      run ${pkgs.rbw}/bin/rbw config set email "$email"
    else
      echo "rbw-config: /run/secrets/bw/email not readable, skipping email" >&2
    fi
    run ${pkgs.rbw}/bin/rbw config set base_url https://vault.bitwarden.com
    run ${pkgs.rbw}/bin/rbw config set pinentry ${pinentrySmart}/bin/pinentry-smart
  '';
}
