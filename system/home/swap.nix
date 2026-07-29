{ ... }:
{
  # High priority so it absorbs memory pressure before the disk swap below.
  zramSwap = {
    enable = true;
    memoryPercent = 50;
    priority = 100;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 16 * 1024; # 16GB
      priority = 10;
    }
  ];
}
