# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  pkgs,
  inputs,
  ...
}:

{
  imports = [
    # Include the results of the hardware scan.
    ./hardware-configuration.nix
  ];

  boot = {
    # 启用 Plymouth，使用默认主题
    plymouth.enable = true;

    # 静默启动参数
    consoleLogLevel = 3;
    initrd.verbose = false;
    kernelParams = [
      "quiet"
      "splash"
      "udev.log_priority=3"
      "rd.systemd.show_status=auto"
    ];

    # 使用 systemd-boot 作为 EFI 启动加载器
    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    # 内核模块和最新内核
    kernelModules = [
      "amd_pstate"
      "amdgpu"
    ];

    kernelPackages = pkgs.linuxPackages_latest;
  };

  documentation.nixos.enable = false;

  networking.hostName = "flowerpot"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.desktopManager.gnome.enable = true;
  environment.gnome.excludePackages = (
    with pkgs;
    [
      atomix # puzzle game
      cheese # webcam tool
      epiphany # web browser
      geary # email reader
      gedit # text editor
      gnome-characters
      gnome-tour
      gnome-photos
      hitori # sudoku game
      iagno # go game
      tali # poker game
      totem # video player
      yelp
      gnome-weather
    ]
  );

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lophophora = {
    isNormalUser = true;
    hashedPassword = "$y$j9T$ywlcAEMJIDVX/1G5Pm5bi1$YSb/zJEgyNykoFHYt0F8b5DZ8mK9GZE.QlQzMfOfUO3";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.fish;
    packages = with pkgs; [
      tree
      ffmpeg
      fastfetch
      imagemagick
      wl-clipboard
      gnome-themes-extra
      gnome-tweaks
    ];
  };

  programs.fish = {
    enable = true;
    promptInit = ''
       function fish_prompt
          set -l nix_shell_info (
              if test -n "$IN_NIX_SHELL"
                  echo -n "<nix-shell> "
              end
          )
          echo -n -s "$nix_shell_info"
          set_color green
          echo -n -s "~>"
          set_color normal
          echo -n " "
          set -l git_status (__fish_git_prompt "%s")
          if test -n "$git_status"
              echo -n -s "($git_status)"
              echo -n " "
          end
      end
    '';
  };

  # programs.firefox.enable = true;

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    nano
    git
    wget
    gnome-sound-recorder
    texlive.combined.scheme-full
    texlab
    inputs.agenix.packages."${system}".default
    nixd
    power-profiles-daemon
    unzip
    nixfmt
  ];

  # dae service

  age.secrets.daeConfig = {
    file = ./secrets/config.dae.age;
    path = "/run/secrets/dae/config.dae"; # Where the decrypted file will be placed
    mode = "600"; # Permissions for the decrypted file
    owner = "root"; # Adjust to the user running dae, if needed
    group = "root";
  };

  services.dae = {
    enable = true;
    configFile = config.age.secrets.daeConfig.path;
  };

  # font config and input method
  fonts = {
    enableDefaultPackages = true;
    packages = with pkgs; [
      noto-fonts-cjk-sans-static
      noto-fonts-cjk-serif-static
      noto-fonts
      ibm-plex
      (ibm-plex.override { families = [ "sans-sc" ]; })
      noto-fonts-extra
      noto-fonts-emoji
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Noto Sans CJK SC" ];
        serif = [ "Noto Serif CJK SC" ];
        monospace = [ "Noto Sans Mono CJK SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      libpinyin
    ];
  };

  nix.settings.experimental-features = [
    "nix-command"
    "flakes"
  ];
  nix.settings.trusted-users = [
    "root"
    "lophophora"
  ];

  programs.git = {
    enable = true;
    config = {
      user = {
        name = "lsdhophora";
        email = "lsdphophora@proton.me";
      };
      init.defaultBranch = "main";
    };
  };

  age.secrets.access-tokens-github = {
    file = ./secrets/access-tokens-github.age;
    path = "/run/agenix/access-tokens-github";
    owner = "root";
    group = "root";
    mode = "600";
  };

  age.identityPaths = [ "/home/lophophora/.ssh/lysergic" ];

  nix.extraOptions = ''
    !include ${config.age.secrets.access-tokens-github.path}
  '';

  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        text-scaling-factor = 1.42;
      };
    }
  ];

  system.stateVersion = "25.05";
}
