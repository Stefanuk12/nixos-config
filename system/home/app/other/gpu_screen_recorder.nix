{ ... }:

{
  # Installs the CLI plus a cap_sys_admin setcap wrapper for gsr-kms-server, needed for promptless
  # KMS capture under Wayland.
  programs.gpu-screen-recorder.enable = true;
}
