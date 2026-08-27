{
  pkgs,
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

  # Declarative WiFi tuning: pin 56-606 to 5 GHz (band a).
  # The 5 GHz AP offers 80 MHz VHT with a stronger signal than the
  # 20 MHz HT 2.4 GHz AP (-54 dBm vs -58 dBm). The connection profile
  # (SSID, password, auth) stays managed by Plasma GUI.
  systemd.services.nm-wifi-tune = {
    description = "Pin NetworkManager WiFi profile to 5 GHz";
    after = [ "NetworkManager.service" ];
    requires = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.networkmanager}/bin/nmcli con mod 56-606 802-11-wireless.band a"
      ];
    };
  };
}
