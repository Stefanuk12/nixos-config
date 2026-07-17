# Module-managed pinentry that reads SETDESC/SETPROMPT to route client__id → $PINENTRY_CLIENT_ID_FILE, client__secret → $PINENTRY_CLIENT_SECRET_FILE, and anything else → $PINENTRY_PASSWORD_FILE.
{ pkgs }:

pkgs.writeShellScriptBin "pinentry-smart" ''
    state="master"
    echo "OK Greetings"
    while IFS= read -r line; do
      cmd="''${line%% *}"
      rest="''${line#* }"
      case "$cmd" in
        SETDESC|SETPROMPT|SETKEYINFO)
          case "$rest" in
            *client__id*)     state="client_id" ;;
            *client__secret*) state="client_secret" ;;
          esac
          echo "OK"
          ;;
        GETPIN)
          case "$state" in
            client_id)     val=$(cat "''${PINENTRY_CLIENT_ID_FILE:?}") ;;
            client_secret) val=$(cat "''${PINENTRY_CLIENT_SECRET_FILE:?}") ;;
            *)             val=$(cat "''${PINENTRY_PASSWORD_FILE:?}") ;;
          esac
          printf 'D %s\nOK\n' "$val"
          # Reset for the next prompt cycle (rbw register asks twice in one session).
          state="master"
          ;;
        BYE) echo "OK"; exit 0 ;;
        *)   echo "OK" ;;
      esac
    done
  ''
