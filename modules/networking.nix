{
  ...
}:

{
  networking.hostName = "flowerpot";

  time.timeZone = "Asia/Shanghai";

  networking.networkmanager = {
    enable = true;
    unmanaged = [ "interface-name:lo" ];
  };

  networking.firewall = {
    enable = true;
    allowedUDPPorts = [ 5353 ]; # mDNS for LocalSend discovery
    allowedTCPPorts = [ 46357 ]; # LocalSend file transfer
  };
}
