{ ... }:
{
  # Compressed in-RAM swap: fast, takes priority so it absorbs everyday
  # memory pressure before anything touches the disk.
  zramSwap = {
    enable = true;
    memoryPercent = 50; # up to ~16GB of compressed swap on this 32GB host
    priority = 100;
  };

  # Disk-backed swap file on the ext4 root: deeper overflow once zram is
  # exhausted. Lower priority so it's only used after zram fills up.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024; # 16GB
      priority = 10;
    }
  ];
}
