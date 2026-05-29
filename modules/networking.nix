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
    allowedUDPPorts = [ 53317 ]; # LocalSend discovery
    allowedTCPPorts = [
      53317
      9090
    ]; # LocalSend file transfer
  };
}
