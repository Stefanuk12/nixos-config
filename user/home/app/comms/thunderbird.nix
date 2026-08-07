{ config, lib, pkgs, ... }:

let
  profileDir = "${config.home.homeDirectory}/.thunderbird/stefan";
  simpleloginXpi = "${profileDir}/extensions/${pkgs.thunderbird-simplelogin.extensionId}.xpi";
in
{
  # `simplelogin-key-sync [rbw-entry]` copies the API key from Bitwarden into a managed-storage
  # manifest. Run by hand after unlocking rbw; not a login service, as rbw needs an unlocked agent.
  home.packages = [ pkgs.thunderbird-simplelogin.keySync ];

  # Make Thunderbird notice a *permissions* change in the rebuilt add-on.
  #
  # Thunderbird decides whether to re-read an installed XPI by comparing its recorded mtime with the
  # file's current one. Every file in the nix store has mtime 1, identically for every build, so that
  # check never fires: a new XPI at the same profile path is treated as unchanged and the cached
  # metadata - version, and crucially the *granted permissions* - is kept. A newly-required
  # permission then stays ungranted and its whole API namespace is undefined at runtime.
  #
  # The remedy is to delete the add-on's records so it installs afresh, but that is not free:
  # Thunderbird allocates a new storage origin for a reinstalled add-on, discarding everything in
  # storage.local - the API key and every setting. So this keys off the permission set alone, not
  # the store path. Background scripts are read from the XPI at run time, so ordinary code changes
  # need no intervention at all; only a permissions change does, and those are rare.
  #
  # Keep the API key in managed storage (`simplelogin-key-sync`) and it survives even this, since
  # managed storage lives outside the profile.
  # A function, not a bare block: home-manager inlines every activation entry into one `set -eu`
  # script, where a top-level `exit` would abandon the rest of activation and a bare `test &&`
  # would abort it on a false test.
  home.activation.thunderbirdSimpleloginRescan =
    lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      thunderbirdSimpleloginRescan() {
        local xpi="${simpleloginXpi}"
        local stamp="${profileDir}/.simplelogin-permissions"
        local fingerprint="${pkgs.thunderbird-simplelogin.permissionsFingerprint}"
        local db tmp

        [ -e "$xpi" ] || return 0
        # Unchanged permissions: nothing to do. Code updates take effect on their own.
        [ "$fingerprint" != "$(cat "$stamp" 2>/dev/null || true)" ] || return 0

        # Thunderbird rewrites both files from memory as it runs, so editing them under a live
        # process would simply be undone.
        if ${pkgs.procps}/bin/pgrep -u "$USER" -x thunderbird > /dev/null 2>&1; then
          warnEcho "thunderbird-simplelogin: permissions changed but Thunderbird is running."
          warnEcho "  Quit Thunderbird and re-run hm-stefan-home to grant them."
          return 0
        fi

        run rm -f "${profileDir}/addonStartup.json.lz4"

        db="${profileDir}/extensions.json"
        if [ -e "$db" ]; then
          tmp="$db.hm-tmp"
          if ${pkgs.jq}/bin/jq --arg id "${pkgs.thunderbird-simplelogin.extensionId}" \
               '.addons |= map(select(.id != $id))' "$db" > "$tmp"; then
            run mv "$tmp" "$db"
          else
            rm -f "$tmp"
            warnEcho "thunderbird-simplelogin: could not rewrite $db; left untouched."
            return 0
          fi
        fi

        warnEcho "thunderbird-simplelogin: permissions changed; the add-on will reinstall on next"
        warnEcho "  start, which clears its settings. Re-run simplelogin-key-sync to restore the key."
        echo "$fingerprint" > "$stamp"
      }
      thunderbirdSimpleloginRescan
    '';

  # The module can't store the mail password, so Thunderbird prompts once on first connect:
  #   rbw get 'Proton hydroxide bridge'
  programs.thunderbird = {
    enable = true;
    languagePacks = [ "en-GB" ];

    profiles."stefan" = {
      isDefault = true;

      settings = {
        "intl.locale.requested" = "en-GB";
        # nixpkgs' Thunderbird ships the en-US dictionary only; add "British English" once via
        # right-click in a compose field if spellcheck flags British spellings.
        "spellchecker.dictionary" = "en-GB";
        # Without this Thunderbird leaves the declaratively-installed add-on disabled on first run.
        "extensions.autoDisableScopes" = 0;
        # The add-on is built locally and unsigned. Already Thunderbird's default; pinned so an
        # upstream flip can't silently disable it.
        "xpinstall.signatures.required" = false;
      };

      # Alias browser + create-on-send. Needs a key: `simplelogin-key-sync`, or paste one under
      # Add-ons -> SimpleLogin Aliases -> Options. Default send mode (reverse-aliases) is the one
      # that works through the hydroxide bridge, and needs a paid SimpleLogin plan.
      extensions = [ pkgs.thunderbird-simplelogin ];
    };
  };

  accounts.email.accounts."proton" = {
    primary = true;
    realName = "Stefan";
    address = "stefanukpadd@protonmail.com";
    userName = "stefanukpadd"; # bridge login is the bare username (matches `hydroxide auth`)

    # Plaintext loopback to the hydroxide bridge; nothing leaves the machine.
    imap = { host = "127.0.0.1"; port = 1143; tls.enable = false; };
    smtp = { host = "127.0.0.1"; port = 1025; tls.enable = false; };

    thunderbird = {
      enable = true;
      profiles = [ "stefan" ];

      # Don't let Thunderbird file its own copy in Sent.
      #
      # Proton stores sent mail server-side the moment it accepts the message, and hydroxide allows
      # IMAP APPEND only into Drafts - so Thunderbird's copy is both redundant and refused, with
      # "cannot create messages outside the Drafts mailbox" after every otherwise-successful send.
      # The message still shows up in Sent once the folder syncs back.
      perIdentitySettings = id: {
        "mail.identity.id_${id}.doFcc" = false;
      };
    };
  };

  # Thunderbird rejects the "google_calendar" type, so Google Calendar is wired as plain caldav.
  # The URL embeds the Calendar ID — for the primary calendar that's the Gmail address; others are
  # under Settings -> Integrate calendar. Auth is OAuth in-browser on first sync.
  accounts.calendar.accounts."google" = {
    primary = true;
    remote = {
      type = "caldav";
      url = "https://apidata.googleusercontent.com/caldav/v2/stefanukpadd@gmail.com/events/";
      userName = "stefanukpadd@gmail.com";
    };
    thunderbird.enable = true;
  };
}
