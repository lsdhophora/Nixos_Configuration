{ lib, pkgs, ... }:

{
  services.tlp = {
    enable = true;
    settings = {
      CPU_SCALING_GOVERNOR_ON_AC = "performance";
      CPU_SCALING_GOVERNOR_ON_BAT = "schedutil";
      CPU_ENERGY_PERF_POLICY_ON_BAT = "power";
      CPU_ENERGY_PERF_POLICY_ON_AC = "performance";
      CPU_BOOST_ON_BAT = 0;
      CPU_BOOST_ON_AC = 1;
      DISK_APM_LEVEL_ON_BAT = "128";
      SATA_LINKPWR_ON_BAT = "med_power_with_dipm";
      PCIE_ASPM_ON_BAT = "powersupersave";
      WIFI_PWR_ON_BAT = 1;
      USB_AUTOSUSPEND = 1;
      RUNTIME_PM_ON_BAT = "auto";
    };
  };
}
