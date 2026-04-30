{ ... }:
{
  # Docker daemon for local integration testing (ScyllaDB, Kafka, etc.
  # via docker-compose). Running as a system service rather than
  # rootless so `docker compose` from the default PATH just works for
  # members of the `docker` group.
  virtualisation.docker = {
    enable = true;
    # Auto-prune unused images/containers weekly so `target/` equivalents
    # don't accumulate to hundreds of GB.
    autoPrune = {
      enable = true;
      dates = "weekly";
      flags = [ "--all" ];
    };
  };
}
