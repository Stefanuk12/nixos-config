{ config, lib, pkgs, ... }:

let
  cfg = config.rbw-fetch;
  useApiKey = cfg.apiClientIdFile != null && cfg.apiClientSecretFile != null;

  # Module-managed pinentry. Reads SETDESC/SETPROMPT to tell which value rbw
  # wants and serves it from the matching file:
  #   "client__id"     → $PINENTRY_CLIENT_ID_FILE     (rbw register)
  #   "client__secret" → $PINENTRY_CLIENT_SECRET_FILE (rbw register)
  #   anything else    → $PINENTRY_PASSWORD_FILE      (rbw login/unlock)
  pinentrySmart = pkgs.writeShellScriptBin "pinentry-smart" ''
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
  '';

  secretOpts = { name, config, ... }: {
    options = {
      outputPath = lib.mkOption {
        type = lib.types.str;
        default = "/run/rbw-fetch/secrets/${name}";
        defaultText = lib.literalExpression ''"/run/rbw-fetch/secrets/<name>"'';
        description = ''
          Where to write the fetched secret. Must be under /run/.
          Defaults to /run/rbw-fetch/secrets/<name>; override only if a
          downstream consumer needs a specific path.
        '';
      };

      # Read-only alias of outputPath, mirroring sops-nix's `.path`, e.g.
      #   credentialsFile = config.rbw-fetch.secrets.pia-creds.path;
      path = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Alias for `outputPath` (mirrors sops-nix's `.path`).";
      };

      # Read-only name of the systemd unit that produces this secret. Use to
      # wire downstream Requires=/After= without hardcoding "rbw-fetch-<name>.service".
      serviceName = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Name of the systemd unit that fetches this secret.";
      };

      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
        description = "File mode applied to the output after the script writes it.";
      };

      script = lib.mkOption {
        type = lib.types.lines;
        example = ''
          user=$(rbw get --field username PrivateInternetAccess)
          pass=$(rbw get PrivateInternetAccess)
          printf '%s\n%s\n' "$user" "$pass" > "$OUT"
        '';
        description = ''
          Shell snippet that uses rbw to fetch values and writes them to $OUT.
          The wrapper handles `rbw login` + `rbw unlock` before this runs and
          `rbw lock` on exit (via trap, so it fires even on failure).

          On entry:
            - rbw and coreutils are on PATH
            - the vault is unlocked
            - OUT is the configured outputPath
            - umask is 077
        '';
      };
    };

    config = {
      path = config.outputPath;
      serviceName = "rbw-fetch-${name}.service";
    };
  };

  mkService = name: secret:
    let
      stripped = lib.removePrefix "/run/" secret.outputPath;
      segments = lib.splitString "/" stripped;
      outputDir = lib.concatStringsSep "/" (lib.init segments);
      runtimeDirs = lib.unique (
        [ "rbw-fetch" ]
        ++ lib.optional (outputDir != "" && outputDir != "rbw-fetch") outputDir
      );
      useEmailFile = cfg.emailFile != null;
    in
    {
      description = "Fetch ${name} from Bitwarden via rbw";
      after = [ "network-online.target" ];
      wants = [ "network-online.target" ];
      path = [ pkgs.rbw pkgs.coreutils pkgs.bash pinentrySmart ];
      serviceConfig = {
        Type = "oneshot";
        RemainAfterExit = true;
        User = "rbw-fetch";
        Group = "rbw-fetch";
        StateDirectory = "rbw-fetch";
        StateDirectoryMode = "0700";
        RuntimeDirectory = runtimeDirs;
        RuntimeDirectoryMode = "0700";
        LoadCredential =
          [ "master_password:${toString cfg.masterPasswordFile}" ]
          ++ lib.optional useEmailFile "email:${toString cfg.emailFile}"
          ++ lib.optionals useApiKey [
            "client_id:${toString cfg.apiClientIdFile}"
            "client_secret:${toString cfg.apiClientSecretFile}"
          ];
        Environment = [
          "HOME=/var/lib/rbw-fetch"
          "XDG_RUNTIME_DIR=/run/rbw-fetch"
        ];
      };
      script = ''
        set -euo pipefail

        ${if useEmailFile
          then ''rbw_email=$(cat "$CREDENTIALS_DIRECTORY/email")''
          else ''rbw_email=${lib.escapeShellArg cfg.email}''}
        rbw config set email "$rbw_email"
        rbw config set base_url ${lib.escapeShellArg cfg.baseUrl}
        ${lib.optionalString (cfg.identityUrl != null)
          "rbw config set identity_url ${lib.escapeShellArg cfg.identityUrl}"}
        rbw config set pinentry ${pinentrySmart}/bin/pinentry-smart

        export PINENTRY_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/master_password"
        ${lib.optionalString useApiKey ''
          export PINENTRY_CLIENT_ID_FILE="$CREDENTIALS_DIRECTORY/client_id"
          export PINENTRY_CLIENT_SECRET_FILE="$CREDENTIALS_DIRECTORY/client_secret"
        ''}
        export OUT="${secret.outputPath}"
        umask 077

        trap 'rbw lock 2>/dev/null || true' EXIT

        if ! rbw login 2>&1; then
          ${if useApiKey then ''
            echo "rbw login failed; registering device with API keys" >&2
            rbw register
            rbw login
          '' else ''
            echo "rbw login failed. If your Bitwarden account has new-device" >&2
            echo "protection, set rbw-fetch.apiClientIdFile and apiClientSecretFile" >&2
            echo "so the module can run `rbw register` first." >&2
            exit 1
          ''}
        fi
        rbw unlock
        rbw sync || echo "rbw sync failed; proceeding with cached vault" >&2

        ${secret.script}

        chmod ${secret.mode} "$OUT"
      '';
    };
in
{
  options.rbw-fetch = {
    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      example = "you@example.com";
      description = ''
        Bitwarden account email (literal). Goes into the Nix store, so use
        `emailFile` if you'd rather keep it out of /nix/store entirely.
        Mutually exclusive with `emailFile`.
      '';
    };

    emailFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the Bitwarden account email. Read at
        service-start time via LoadCredential, same shape as
        `masterPasswordFile`. Mutually exclusive with `email`.
      '';
    };

    baseUrl = lib.mkOption {
      type = lib.types.str;
      default = "https://vault.bitwarden.com";
      description = "Bitwarden API base URL. Override for self-hosted Vaultwarden.";
    };

    identityUrl = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Optional Bitwarden identity URL (rarely needed; defaults to baseUrl).";
    };

    masterPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to a file containing the Bitwarden master password. Typically a
        sops-nix or agenix secret path. Read via systemd LoadCredential at
        service-start time — the underlying file just needs to exist before
        the service runs.
      '';
    };

    apiClientIdFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing your Bitwarden personal API `client_id`
        (find it under Settings → Security → Keys → "View API Key").

        Required only if your account has "new device login protection"
        enabled — the module runs `rbw register` with these keys on first
        login from this machine, then falls through to normal `rbw login`.

        Must be set together with `apiClientSecretFile`.
      '';
    };

    apiClientSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Counterpart to `apiClientIdFile`. See its description.";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule secretOpts);
      default = { };
      description = ''
        Map of secret names to fetcher configs. Each entry creates a
        `rbw-fetch-<name>.service` oneshot that writes a file at outputPath.
        Wire downstream services with Requires= / After= on that unit, and
        reference the path via `config.rbw-fetch.secrets.<name>.path`.
      '';
    };
  };

  config = lib.mkIf (cfg.secrets != { }) {
    assertions = [
      {
        assertion = (cfg.email != null) != (cfg.emailFile != null);
        message = "rbw-fetch: set exactly one of `email` or `emailFile`.";
      }
      {
        assertion = (cfg.apiClientIdFile == null) == (cfg.apiClientSecretFile == null);
        message = "rbw-fetch: set apiClientIdFile and apiClientSecretFile together, or neither.";
      }
    ];

    users.users.rbw-fetch = {
      isSystemUser = true;
      group = "rbw-fetch";
      home = "/var/lib/rbw-fetch";
      description = "rbw-fetch service user";
    };
    users.groups.rbw-fetch = { };

    systemd.services = lib.mapAttrs' (
      name: secret: lib.nameValuePair "rbw-fetch-${name}" (mkService name secret)
    ) cfg.secrets;
  };
}
