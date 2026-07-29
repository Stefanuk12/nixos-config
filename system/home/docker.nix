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
}
