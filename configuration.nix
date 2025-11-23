# Edit this configuration file to define what should be installed on
# your system. Help is available in the configuration.nix(5) man page, on
# https://search.nixos.org/options and in the NixOS manual (`nixos-help`).

{
  config,
  pkgs,
  inputs,
  lib,
  ...
}:

{
  imports = [
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

    kernelPackages = pkgs.linuxPackages_zen;
  };

  documentation.nixos.enable = false;

  networking.hostName = "flowerpot"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;
  nixpkgs.overlays = [
    (final: prev: {
      gnome-sound-recorder = prev.gnome-sound-recorder.overrideAttrs (old: {
        prePatch = ''
          waveformJs=$(find "$PWD" -name 'waveform.js' -path '*/src/*')
          substituteInPlace "$waveformJs" \
            --replace-fail \
              'this._peaks.unshift(p.toFixed(2));' \
              'if(this._warmup-- > 0)return;this._peaks.unshift(Math.max(0,Math.min(1,p)));' \
            --replace-fail \
              'this._peaks = [];' \
              'this._peaks=[];this._warmup=5;' \
            --replace-fail \
              'this._peaks = p;' \
              'this._peaks = (this.waveType === 1 && p.length > 1) ? p.slice(1) : p;'
        '';
        postPatch = ''
          chmod +x build-aux/meson_post_install.py
          substituteInPlace build-aux/meson_post_install.py \
            --replace-fail 'gtk-update-icon-cache' 'gtk4-update-icon-cache'
          patchShebangs build-aux/meson_post_install.py
          substituteInPlace data/ui/row.ui \
            --replace-fail emblem-ok-symbolic object-select-symbolic
        '';
      });
    })
  ];
  environment.gnome.excludePackages = (
    with pkgs;
    [
      atomix
      cheese
      geary
      gedit
      epiphany
      gnome-characters
      gnome-tour
      gnome-photos
      hitori
      iagno
      tali
      totem
      yelp
      gnome-weather
      gnome-software
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
      (texlive.combine {
        inherit (texlive)
          scheme-basic # Basic TeX scheme
          ctex # Chinese support
          chinese-jfm # Chinese support
          fontspec # Custom fonts
          luatex # LuaLaTeX engine
          luacode # Lua code in LaTeX
          graphics # Image inclusion
          geometry # Page margins
          fancyhdr # Headers/footers
          titlesec
          hyphen-greek
          hyperref # Hyperlinks
          postnotes # Endnotes
          eso-pic # Background images
          footmisc # Footnote formatting
          polyglossia # Multilingual support
          wrapfig
          capt-of
          unicode-math
          lualatex-math
          selnolig
          everypage
          ;
      })
      pandoc
      texlab
      nixfmt
      nixd
      unzip
      gnome-sound-recorder
      gnome-themes-extra
      gnome-tweaks
      papers
      showtime
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

      function zathura
        command zathura $argv 2>/dev/null
      end
    '';
  };

  # List packages installed in system profile.
  # You can use https://search.nixos.org/ to find more packages (and options).
  environment.systemPackages = with pkgs; [
    nano
    git
    wget
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
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
    fontDir.enable = true;
    packages = with pkgs; [
      noto-fonts-cjk-sans-static
      noto-fonts-cjk-serif-static
      noto-fonts
      ibm-plex
      (ibm-plex.override { families = [ "sans-sc" ]; })
      noto-fonts-color-emoji
    ];
    fontconfig = {
      enable = true;
      defaultFonts = {
        sansSerif = [ "Noto Sans CJK SC" ];
        serif = [ "Noto Serif CJK SC" ];
        monospace = [ "Noto Sans Mono CJK SC" ];
        emoji = [ "Noto Color Emoji" ];
      };
      localConf = ''
        <fontconfig>
          <match target="pattern">
            <test name="family">
              <string>IBM Plex Sans</string>
            </test>
            <edit name="weight" mode="assign">
              <int>100</int>
            </edit>
          </match>
        </fontconfig>
      '';
    };
  };

  i18n.inputMethod = {
    enable = true;
    type = "ibus";
    ibus.engines = with pkgs.ibus-engines; [
      rime
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
        cursor-size = lib.gvariant.mkInt32 32;
      };
    }
  ];

  networking.firewall.enable = false;

  system.stateVersion = "25.05";
}
