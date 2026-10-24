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

  home.packages = [
    # nixpkgs pins 1.9.3, which mangles "Edit in Studio" deeplinks. Drop once it ships 1.9.4+.
    (pkgs.vinegar.overrideAttrs (old: rec {
      version = "1.9.4";
      src = pkgs.fetchFromGitHub {
        owner = "vinegarhq";
        repo = "vinegar";
        tag = "v${version}";
        hash = "sha256-5RwRiHVOYxMBL92Z8H+0VxJtz6Y7yXpv70UqesLINCk=";
      };
      vendorHash = "sha256-kS8awIGI5xHY4i7hvKMLcZKdMiFaoirokd3TSpMbC8c=";

      # 1.9.4 moved the wine-root pin to internal/config/config.go, so nixpkgs' postPatch no longer
      # applies; re-bake the packaged wine into the new location.
      postPatch =
        let
          wine = pkgs.lib.findFirst (p: pkgs.lib.hasPrefix "wine64-" (p.name or "")) (
            throw "vinegar: wine not found in buildInputs"
          ) old.buildInputs;
        in
        ''
          substituteInPlace Makefile \
            --replace-fail 'gtk-update-icon-cache' '${pkgs.lib.getExe' pkgs.gtk4 "gtk4-update-icon-cache"}'
          substituteInPlace internal/config/config.go \
            --replace-fail 'cfg.Studio.WineRoot = dirs.WinePath' 'cfg.Studio.WineRoot = "${wine}"'
        '';
    }))
  ];
}
