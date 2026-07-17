{ ... }:

{
  # GPU Screen Recorder (ShadowPlay-style instant replay); the module installs the CLI + a cap_sys_admin setcap wrapper for gsr-kms-server, needed for promptless KMS capture under Wayland.
  programs.gpu-screen-recorder.enable = true;
}
