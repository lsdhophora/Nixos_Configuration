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
      # OLED: the OEM brightness curve has a broken point near the top.
      # 100% then maps to about 0 nits (dimmer than 95%). Disable the curve.
      "amdgpu.dcdebugmask=0x40000"
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

    kernelPackages = pkgs.linuxPackages_latest;
  };

  console = {
    font = "ter-132n";
    packages = with pkgs; [ terminus_font ];
  };

  # sched_ext scheduler: replaces the fair-class scheduler entirely, so
  # CFS/EEVDF tweaks like the BORE patch are inert while it runs. BORE was
  # tried (patches/kernel/bore-7.2.patch) and rolled back: scx_lavd gives
  # equal-or-better interactive responsiveness under full CPU load with no
  # kernel rebuilds. Requires a kernel with CONFIG_SCHED_EXT (=y in the
  # mainline config used by linuxPackages_latest).
  services.scx = {
    enable = true;
    scheduler = "scx_lavd";
  };

  swapDevices = [ ];

  boot.tmp.cleanOnBoot = true;

  documentation.nixos.enable = false;
}
