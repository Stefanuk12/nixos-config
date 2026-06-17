{ ... }:
{
  # Docker daemon for local integration testing; system service (not rootless) so `docker compose` works for the `docker` group.
  virtualisation.docker = {
    enable = true;
    # Auto-prune unused images/containers weekly to avoid disk bloat.
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };
}
