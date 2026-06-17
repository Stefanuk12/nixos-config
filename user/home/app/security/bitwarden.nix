{ pkgs, lib, ... }:

let
  # Pinentry that serves the rbw master password from a sops-decrypted file so
  # `rbw unlock`/`rofi-rbw` never prompt. Refuses to serve it to rbw register
  # prompts (client__id/client__secret) — use pinentry-qt for those instead.
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

  # Plain F1-F12 (no modifier): Hyprland doesn't grab them, rofi's defaults don't
  # use them, and they can't clash with typed search input.
  xdg.configFile."rofi-rbw.rc".text = ''
    keybindings = F1:type:username:tab:password,F2:type:username,F3:type:password,F4:type:totp,F5:copy:password,F6:copy:username,F7:copy:totp,F8::menu,F9:sync
    menu-keybindings = F2:type,F5:copy
  '';

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
