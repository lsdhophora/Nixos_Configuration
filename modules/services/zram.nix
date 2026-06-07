{ ... }:
{
  zramSwap = {
    enable = true;
    algorithm = "zstd";
    memoryPercent = 75;
    swapDevices = 1;
    priority = 100;
  };
}
