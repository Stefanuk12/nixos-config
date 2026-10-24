{ pkgs, ... }:

let
  # Flatpak only mounts the NVIDIA userspace when an extension whose branch matches the host
  # driver *exactly* is installed; otherwise the sandbox sees mesa ICDs alone and Sober renders
  # on the iGPU. Tracks hardware.nvidia.package, which is also nvidiaPackages.stable.
  nvidiaGl =
    "org.freedesktop.Platform.GL.nvidia-"
    + builtins.replaceStrings [ "." ] [ "-" ] pkgs.linuxPackages.nvidiaPackages.stable.version
    + "//1.4";
in
{
  # Flathub-only.
  services.flatpak.packages = [
    "org.vinegarhq.Sober"
    nvidiaGl
  ];

  # Rich Presence.
  services.flatpak.overrides."org.vinegarhq.Sober".Context.filesystems = [
    "xdg-run/app/com.discordapp.Discord:create"
    "xdg-run/discord-ipc-0"
  ];

  # Sober is Vulkan-only, so the optimus layer is what picks the card. Both vars go inert when the
  # dGPU is on vfio-pci: the layer ships inside the extension above, which flatpak stops mounting
  # once the nvidia module is unloaded, and Sober falls back to the iGPU instead of failing.
  services.flatpak.overrides."org.vinegarhq.Sober".Environment = {
    __NV_PRIME_RENDER_OFFLOAD = "1";
    __VK_LAYER_NV_optimus = "NVIDIA_only";
  };

  home.packages = [ pkgs.vinegar ];
}
