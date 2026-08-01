# Which GPU an app's EGL/Vulkan/GLX loader is allowed to see. The Vulkan loader opens every ICD it
# finds, so leaving nvidia_icd.json visible is enough for a Chromium app to pin the dGPU's render
# node for its whole lifetime, which blocks the rmmod in dgpu-disable. Desktop apps therefore get
# mesa only and games opt back in.
let
  mesaEgl = "/run/opengl-driver/share/glvnd/egl_vendor.d/50_mesa.json";
  nvidiaEgl = "/run/opengl-driver/share/glvnd/egl_vendor.d/10_nvidia.json";

  mesaVk = builtins.concatStringsSep ":" [
    "/run/opengl-driver/share/vulkan/icd.d/radeon_icd.x86_64.json"
    "/run/opengl-driver-32/share/vulkan/icd.d/radeon_icd.i686.json"
  ];
  nvidiaVk = builtins.concatStringsSep ":" [
    "/run/opengl-driver/share/vulkan/icd.d/nvidia_icd.json"
    "/run/opengl-driver-32/share/vulkan/icd.d/nvidia_icd.json"
  ];

  dgpu = {
    __EGL_VENDOR_LIBRARY_FILENAMES = "${nvidiaEgl}:${mesaEgl}";
    VK_DRIVER_FILES = "${nvidiaVk}:${mesaVk}";
    __GLX_VENDOR_LIBRARY_NAME = "nvidia";
    __NV_PRIME_RENDER_OFFLOAD = "1";
    __NV_PRIME_RENDER_OFFLOAD_PROVIDER = "NVIDIA-G0";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
  };

  # Guarded because the dGPU sits on vfio-pci most of the time, and __GLX_VENDOR_LIBRARY_NAME=nvidia
  # with no bound card fails outright rather than falling back. The glob stays literal when nothing
  # matches, so [ -e ] is false and the app quietly runs on the iGPU.
  preferDgpu = ''
    for _dgpu in /sys/bus/pci/drivers/nvidia/0000:*; do
      if [ -e "$_dgpu" ]; then
    ${builtins.concatStringsSep "\n" (
      map (n: "    export ${n}=${dgpu.${n}}") (builtins.attrNames dgpu)
    )}
        break
      fi
    done
  '';
in
{
  inherit preferDgpu;

  igpu = {
    __EGL_VENDOR_LIBRARY_FILENAMES = mesaEgl;
    VK_DRIVER_FILES = mesaVk;
    __GLX_VENDOR_LIBRARY_NAME = "mesa";
  };

  onDgpu =
    pkgs: pkg:
    pkgs.symlinkJoin {
      name = "${pkg.pname or pkg.name}-dgpu";
      paths = [ pkg ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        for bin in "$out"/bin/*; do
          [ -x "$bin" ] || continue
          wrapProgram "$bin" --run ${pkgs.lib.escapeShellArg preferDgpu}
        done
      '';
    };
}
