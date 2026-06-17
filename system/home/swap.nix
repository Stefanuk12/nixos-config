{ ... }:
{
  # Compressed in-RAM swap; high priority so it absorbs memory pressure before hitting disk.
  zramSwap = {
    enable = true;
    memoryPercent = 50; # up to ~16GB of compressed swap on this 32GB host
    priority = 100;
  };

  # Disk-backed swap file; lower priority, only used once zram fills up.
  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024; # 16GB
      priority = 10;
    }
  ];
}
