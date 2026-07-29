{ pkgs, ... }:

{
  # `simplelogin-key-sync [rbw-entry]` copies the API key from Bitwarden into a managed-storage
  # manifest. Run by hand after unlocking rbw; not a login service, as rbw needs an unlocked agent.
  home.packages = [ pkgs.thunderbird-simplelogin.keySync ];

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
