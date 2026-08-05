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
      { from = 60000; to = 61000; } # mosh
    ];
  };

  # Declarative WiFi tuning: reduce AP switching for 56-606.
  # The connection profile (SSID, password, auth) stays managed by Plasma GUI.
  # This oneshot only sets band preference and clears any BSSID lock.
  systemd.services.nm-wifi-tune = {
    description = "Tune NetworkManager WiFi profiles for reduced AP switching";
    after = [ "NetworkManager.service" ];
    requires = [ "NetworkManager.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = [
        "${pkgs.networkmanager}/bin/nmcli con mod 56-606 802-11-wireless.band bg"
      ];
    };
  };
}
