{ pkgs, ... }:

{
  boot = {
    plymouth = {
      enable = true;
      theme = "bgrt";
    };
    consoleLogLevel = 0;
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
      "systemd.show_status=false"
      "rd.systemd.show_status=false"
      "systemd.log_level=emerg"
      "rd.systemd.log_level=emerg"
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

    kernelPackages = pkgs.linuxPackages_cachyos;
  };

  console = {
    font = "ter-132n";
    packages = with pkgs; [ terminus_font ];
  };

  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  swapDevices = [
    {
      device = "/var/lib/swapfile";
      size = 32 * 1024;
    }
  ];

  documentation.nixos.enable = false;
}
