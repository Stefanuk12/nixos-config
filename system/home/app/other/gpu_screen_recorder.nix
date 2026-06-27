{ ... }:

{
  # GPU Screen Recorder: ShadowPlay/Medal-style instant replay.
  # The module installs the CLI and a cap_sys_admin setcap wrapper for
  # gsr-kms-server, which is required for promptless KMS capture under Wayland.
  programs.gpu-screen-recorder.enable = true;
}
