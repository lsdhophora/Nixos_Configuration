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

  # TCP keepalive: probe idle connections every 60 s and drop dead links
  # after 6 unanswered probes (10 s apart). Prevents NAT/firewall idle
  # timeouts from silently killing SSH and other long-lived connections.
  boot.kernel.sysctl = {
    "net.ipv4.tcp_keepalive_time" = 60;
    "net.ipv4.tcp_keepalive_intvl" = 10;
    "net.ipv4.tcp_keepalive_probes" = 6;
  };
}
