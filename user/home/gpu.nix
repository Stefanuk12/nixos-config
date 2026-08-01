{ pkgs, ... }:

let
  gpuEnv = import ../../hosts/home/gpu-env.nix;
in
{
  home.sessionVariables = gpuEnv.igpu;

  home.packages = [
    (pkgs.writeShellScriptBin "dgpu-run" ''
      ${gpuEnv.preferDgpu}
      exec "$@"
    '')
  ];
}
