{ pkgs, ... }:

let
  protonAddress = "stefanukpadd@protonmail.com";

  # hydroxide registered the account under the bare username (the key in its auth.json) and the
  # bridge authenticates against exactly that. Must match `hydroxide auth <username>`.
  bridgeUser = "stefanukpadd";
in
{
  programs.aerc = {
    enable = true;

    extraConfig = {
      general = {
        # accounts.conf is symlinked out of the world-readable store, which aerc otherwise refuses
        # to load. Safe: the password is fetched at runtime by the cred-cmds below.
        unsafe-accounts-conf = true;
      };
      ui = {
        sidebar-width = 24;
        threading-enabled = true;
      };
    };

    extraAccounts = {
      Proton = {
        from = "Stefan <${protonAddress}>";

        # Plaintext loopback to hydroxide; nothing leaves the machine.
        source = "imap+insecure://${bridgeUser}@127.0.0.1:1143";
        outgoing = "smtp+insecure://${bridgeUser}@127.0.0.1:1025";

        # Unlocks without a prompt: the rbw master password is itself a sops secret served by
        # pinentry-smart.
        source-cred-cmd = "${pkgs.rbw}/bin/rbw get 'Proton hydroxide bridge'";
        outgoing-cred-cmd = "${pkgs.rbw}/bin/rbw get 'Proton hydroxide bridge'";

        default = "INBOX";
        copy-to = "Sent";
        cache-headers = true;
      };
    };
  };

  # Third-party Proton bridge; the official one needs a paid plan.
  home.packages = [ pkgs.hydroxide ];

  # Restart-loops until authed once, with the SAME -app-version flag:
  #   rbw get 'Proton account' | hydroxide -app-version web-mail@5.0.124.7 auth stefanukpadd@proton.me
  systemd.user.services.hydroxide = {
    Unit = {
      Description = "hydroxide ProtonMail bridge";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      # Without a real webapp version string hydroxide sends "Other", which trips Proton's anti-bot
      # and forces the 9001 CAPTCHA at login. Bump from Proton web's "x-pm-appversion" header if rejected.
      ExecStart = "${pkgs.hydroxide}/bin/hydroxide -app-version web-mail@5.0.125.8 serve";
      Restart = "on-failure";
      RestartSec = 10;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
