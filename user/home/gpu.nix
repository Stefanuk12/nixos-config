{ pkgs, ... }:

let
  gpuEnv = import ../../hosts/home/gpu-env.nix;
in
{
  home.sessionVariables = gpuEnv.igpu;

  # hm-session-vars.sh only reaches login shells, but launcher-started apps are systemd scopes
  # under the user manager, so they miss the pin entirely and a Chromium app loads
  # libEGL_nvidia, which holds the dGPU's render node and blocks dgpu-disable.
  systemd.user.sessionVariables = gpuEnv.igpu;

  home.packages = [
    (pkgs.writeShellScriptBin "dgpu-run" ''
      ${gpuEnv.preferDgpu}
      exec "$@"
    '')
  ];
}
