{ pkgs, ... }:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "bgrt";
    };
    consoleLogLevel = 3;
    initrd = {
      systemd.enable = true;
      verbose = false;
      kernelModules = [ "amdgpu" ];
    };
    kernelParams = [
      "quiet"
      "splash"
      "plymouth.use-simpledrm"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
      "model=dell-headset-multi"
    ];

    extraModprobeConfig = ''
      options snd_hda_intel power_save=0
      options snd_hda_intel power_save_controller=N
    '';

    loader.grub = {
      enable = true;
      device = "nodev";
      efiSupport = true;
    };
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
