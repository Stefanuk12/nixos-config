{ ... }:
{
  # System service rather than rootless, so `docker compose` works for the `docker` group.
  virtualisation.docker = {
    enable = true;
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };

  # The CDI generator runs at boot, when the dGPU is still on vfio-pci, so it writes an empty spec.
  # After dgpu-enable: `sudo systemctl restart nvidia-container-toolkit-cdi-generator`.
  hardware.nvidia-container-toolkit.enable = true;
}
