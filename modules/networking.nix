{
  ...
}:

{
  networking.hostName = "flowerpot";

  time.timeZone = "Asia/Shanghai";

  networking.networkmanager = {
    enable = true;
    unmanaged = [ "interface-name:lo" ];
    wifi.powersave = false;
  };

  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 53317 ]; # LocalSend discovery
    allowedTCPPorts = [ 53317 ]; # LocalSend file transfer
    allowedUDPPortRanges = [
      {
        from = 60000;
        to = 61000;
      } # mosh
    ];
  };

  # WiFi roaming is left to NetworkManager defaults: no band pinning,
  # so the client roams freely between the 2.4 GHz and 5 GHz APs of 56-606.
}
