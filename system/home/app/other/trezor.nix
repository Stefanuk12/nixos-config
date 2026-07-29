{ ... }:

{
  # Also installs the udev rules, without which nothing can reach the USB device (uaccess, so no
  # extra group needed). Daemon listens on localhost:21325.
  services.trezord.enable = true;
}
