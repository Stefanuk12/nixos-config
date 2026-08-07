{ ... }:

{
  services.sunshine = {
    enable = true;
    # DRM/KMS capture, which is the only backend that sees a Hyprland session — and, being a read
    # of the scanout framebuffer, the only one that still streams once the session is locked.
    capSysAdmin = true;
    # Off, not on: tailscale0 is already a trusted interface, so Moonlight reaches this over the
    # tailnet either way. Opening the ports globally would only add the LAN — every VM, every IoT
    # device — to the set of things that can reach the pairing endpoint and the :47990 admin UI.
    openFirewall = false;
    autoStart = true;
  };

  # `settings` is deliberately unset: any value beyond the default port makes the module render a
  # config file, and Sunshine then refuses to save from the web UI on :47990 — which is where
  # pairing happens.

  # The module enables uinput but leaves the group membership to the caller, and Sunshine ships no
  # udev rules of its own. Without this /dev/uinput is 0660 root:uinput, so the stream comes up
  # fine and then ignores every key and click.
  users.users.stefan.extraGroups = [ "uinput" ];
}
