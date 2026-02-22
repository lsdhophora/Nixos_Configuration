{
  pkgs,
  lib,
  ...
}:

{
  boot = {
    plymouth.enable = true;
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "model=dell-headset-multi"
    ];

    extraModprobeConfig = ''
      options snd_hda_intel power_save=0
      options snd_hda_intel power_save_controller=N
    '';

    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelPackages = pkgs.linuxPackages_zen;
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024;
    }
  ];

  documentation.nixos.enable = false;
}
