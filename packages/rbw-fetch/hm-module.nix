{ config, lib, pkgs, ... }:

let
  cfg = config.rbw-fetch;
  useApiKey = cfg.apiClientIdFile != null && cfg.apiClientSecretFile != null;
  useEmailFile = cfg.emailFile != null;

  rbw = "${pkgs.rbw}/bin/rbw";

  # Same protocol-aware pinentry as the NixOS module.
  pinentrySmart = import ./pinentry-smart.nix { inherit pkgs; };

  secretOpts = { name, config, ... }: {
    options = {
      outputPath = lib.mkOption {
        type = lib.types.str;
        default = "$XDG_RUNTIME_DIR/rbw-fetch/secrets/${name}";
        defaultText = lib.literalExpression ''"$XDG_RUNTIME_DIR/rbw-fetch/secrets/<name>"'';
        description = ''
          Where to write the fetched secret. The default contains the shell
          variable `$XDG_RUNTIME_DIR` which expands at script-run time to
          `/run/user/<uid>` (a tmpfs only the user can read). Downstream
          consumers in the same user session can resolve it the same way.

          If you need a concrete path at Nix-eval time (e.g. to pass to
          another module), override with an absolute path.
        '';
      };

      path = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Alias for `outputPath` (mirrors sops-nix's `.path`).";
      };

      serviceName = lib.mkOption {
        type = lib.types.str;
        readOnly = true;
        description = "Name of the systemd user unit that fetches this secret.";
      };

      mode = lib.mkOption {
        type = lib.types.str;
        default = "0600";
        description = "File mode applied to the output after the script writes it.";
      };

      script = lib.mkOption {
        type = lib.types.lines;
        description = ''
          Shell snippet that uses rbw to fetch values and writes them to $OUT.
          The wrapper handles `rbw login` + `rbw unlock` before this runs and
          `rbw lock` on exit. On entry: rbw is on PATH, the vault is unlocked,
          OUT is the configured outputPath, umask is 077.
        '';
      };
    };

    config = {
      path = config.outputPath;
      serviceName = "rbw-fetch-${name}.service";
    };
  };

  mkService = name: secret: {
    Unit = {
      Description = "Fetch ${name} from Bitwarden via rbw";
      After = [ "default.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      RuntimeDirectory = "rbw-fetch/secrets";
      RuntimeDirectoryMode = "0700";
      LoadCredential =
        [ "master_password:${toString cfg.masterPasswordFile}" ]
        ++ lib.optional useEmailFile "email:${toString cfg.emailFile}"
        ++ lib.optionals useApiKey [
          "client_id:${toString cfg.apiClientIdFile}"
          "client_secret:${toString cfg.apiClientSecretFile}"
        ];
      ExecStart = pkgs.writeShellScript "rbw-fetch-${name}" ''
        set -euo pipefail

        ${if useEmailFile
          then ''rbw_email=$(cat "$CREDENTIALS_DIRECTORY/email")''
          else ''rbw_email=${lib.escapeShellArg cfg.email}''}
        ${rbw} config set email "$rbw_email"
        ${rbw} config set base_url ${lib.escapeShellArg cfg.baseUrl}
        ${lib.optionalString (cfg.identityUrl != null)
          "${rbw} config set identity_url ${lib.escapeShellArg cfg.identityUrl}"}
        ${rbw} config set pinentry ${pinentrySmart}/bin/pinentry-smart

        export PINENTRY_PASSWORD_FILE="$CREDENTIALS_DIRECTORY/master_password"
        ${lib.optionalString useApiKey ''
          export PINENTRY_CLIENT_ID_FILE="$CREDENTIALS_DIRECTORY/client_id"
          export PINENTRY_CLIENT_SECRET_FILE="$CREDENTIALS_DIRECTORY/client_secret"
        ''}
        export OUT="${secret.outputPath}"
        umask 077

        trap '${rbw} lock 2>/dev/null || true' EXIT

        if ! ${rbw} login 2>&1; then
          ${if useApiKey then ''
            echo "rbw login failed; registering device with API keys" >&2
            ${rbw} register
            ${rbw} login
          '' else ''
            echo "rbw login failed. If your account has new-device protection," >&2
            echo "set rbw-fetch.apiClientIdFile and apiClientSecretFile." >&2
            exit 1
          ''}
        fi
        ${rbw} unlock
        ${rbw} sync || echo "rbw sync failed; proceeding with cached vault" >&2

        ${secret.script}

        # outputPath may contain $XDG_RUNTIME_DIR etc.; let the shell expand it.
        chmod ${secret.mode} "$OUT"
      '';
    };
  };
in
{
  options.rbw-fetch = {
    email = lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      description = "Bitwarden account email (literal). Mutually exclusive with `emailFile`.";
    };

    emailFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing the Bitwarden account email. Must be
        readable by the home-manager user (set `owner` on the sops secret).
        Mutually exclusive with `email`.
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
      description = "Optional Bitwarden identity URL.";
    };

    masterPasswordFile = lib.mkOption {
      type = lib.types.path;
      description = ''
        Path to the Bitwarden master password file. Must be readable by the
        home-manager user.
      '';
    };

    apiClientIdFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = ''
        Path to a file containing your Bitwarden personal API `client_id`.
        Required only if your account has "new device login protection";
        the module runs `rbw register` with these keys on first run.
        Must be set together with `apiClientSecretFile`.
      '';
    };

    apiClientSecretFile = lib.mkOption {
      type = lib.types.nullOr lib.types.path;
      default = null;
      description = "Counterpart to `apiClientIdFile`.";
    };

    secrets = lib.mkOption {
      type = lib.types.attrsOf (lib.types.submodule secretOpts);
      default = { };
      description = ''
        Map of secret names to fetcher configs. Each entry creates a
        `rbw-fetch-<name>.service` user oneshot. Trigger with
        `systemctl --user start rbw-fetch-<name>` or wire other user units
        to depend on it.
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

    home.packages = [ pinentrySmart pkgs.rbw ];

    systemd.user.services = lib.mapAttrs' (
      name: secret: lib.nameValuePair "rbw-fetch-${name}" (mkService name secret)
    ) cfg.secrets;
  };
}
