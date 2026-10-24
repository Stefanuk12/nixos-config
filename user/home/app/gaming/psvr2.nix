{ inputs, pkgs, ... }:

let
  gpuEnv = import ../../../../hosts/home/gpu-env.nix;
  psvr2 = inputs.psvr2-toolkit.packages.${pkgs.stdenv.hostPlatform.system};

  # The session pins apps to mesa, which leaves the compositor on the iGPU and vkGetDrmDisplayEXT
  # failing; naming the connector skips the iGPU's card, which is offered for lease first.
  monado = pkgs.symlinkJoin {
    name = "monado-psvr2-wrapped";
    paths = [ pkgs.monado-psvr2 ];
    nativeBuildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/monado-service \
        --set VK_DRIVER_FILES ${gpuEnv.dgpuOnly.VK_DRIVER_FILES} \
        --set XRT_COMPOSITOR_WAYLAND_CONNECTOR DP-3
    '';
  };

  # OpenXR finds a runtime through XR_RUNTIME_JSON; OpenVR titles go through OpenComposite, which
  # VR_OVERRIDE points at in place of SteamVR's runtime. Set per-app rather than in
  # openvrpaths.vrpath, which psvr2-toolkit-install owns and points at SteamVR.
  monado-run = pkgs.writeShellApplication {
    name = "monado-run";
    text = ''
      export XR_RUNTIME_JSON=${monado}/share/openxr/1/openxr_monado.json
      export VR_OVERRIDE=${pkgs.opencomposite}/lib/opencomposite
      # The client renders on the compositor's GPU or the shared semaphore import fails
      # (vkImportSemaphoreFdKHR: VK_ERROR_UNKNOWN); mesa-only would land it on the iGPU.
      export VK_DRIVER_FILES=${gpuEnv.dgpuOnly.VK_DRIVER_FILES}
      exec "$@"
    '';
  };
in
{
  imports = [ inputs.psvr2-toolkit.homeManagerModules.default ];

  # Native OpenXR path for the headset, alongside the SteamVR one. Detects the HMD (head, eyes,
  # face) but not the Sense controllers, so it is a fallback rather than a replacement.
  home.packages = [
    monado
    monado-run
  ];

  # Not wanted-by anything: the headset is only leasable when the session came up with the dGPU
  # bound, and it takes over DP-3 for as long as it runs.
  systemd.user.services.monado = {
    Unit.Description = "Monado OpenXR runtime for the PSVR2";
    Service = {
      Type = "simple";
      ExecStart = "${monado}/bin/monado-service";
      # monado-service polls stdin and exits if it is not pollable.
      StandardInput = "null";
      Restart = "no";
    };
  };

  programs.psvr2-toolkit = {
    enable = true;

    # OpenVR clients must sit on the compositor's GPU, and Steam already launches SteamVR on the dGPU.
    playAreaSetup.package = gpuEnv.onDgpu pkgs psvr2.psvr2-unity-setup;

    steamvrSettings = {
      steamvr = {
        enableHomeApp = false;
        haveStartedTutorialForNativeChaperoneDriver = true;
        overlayRenderQuality_2 = 3;
        preferredRefreshRate = 120;
        showAdvancedSettings = true;
        showMirrorView = false;
        supersampleManualOverride = true;
      };
      # Sense controllers never show up while SteamVR's gamepad driver is on.
      driver_gamepad.enable = false;
      # The PSVR2's proximity sensor drops SteamVR into standby within seconds of the headset
      # leaving your face, and a paused compositor swallows all controller input.
      power.pauseCompositorOnStandby = false;
    };
  };

  # vrcompositor takes the first Vulkan device, and vrserver spawns it through Steam's launcher
  # service with only a whitelist of variables, so its GPU is picked by Steam's own environment
  # (gpu-env's preferDgpu), not by anything set here.
  programs.steam-launch-options.appLaunchOptions."250820" = "QT_QPA_PLATFORM=xcb %command%";
}
