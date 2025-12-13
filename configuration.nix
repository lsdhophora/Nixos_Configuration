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

    loader.systemd-boot.enable = true;
    loader.efi.canTouchEfiVariables = true;

    kernelModules = [
      "amdgpu"
    ];

    kernelPackages = pkgs.linuxPackages;
  };

  documentation.nixos.enable = false;

  networking.hostName = "flowerpot"; # Define your hostname.

  # Set your time zone.
  time.timeZone = "Asia/Shanghai";

  # Set my networks
  networking.networkmanager = {
    enable = true;

    # Configure unmanaged devices (e.g., loopback interface)
    unmanaged = [ "interface-name:lo" ];
  };

  # Enable the GNOME Desktop Environment.
  services.displayManager.gdm.enable = true;
  services.displayManager.gdm.wayland = true;
  services.desktopManager.gnome.enable = true;
  services.desktopManager.gnome.extraGSettingsOverrides = ''
    [org.gnome.mutter]
    experimental-features=['scale-monitor-framebuffer', 'xwayland-native-scaling']
  '';

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
      gnome-console
    ]
  );

  # Define a user account. Don't forget to set a password with ‘passwd’.
  users.users.lophophora = {
    isNormalUser = true;
    description = "费雪";
    hashedPassword = "$y$j9T$ywlcAEMJIDVX/1G5Pm5bi1$YSb/zJEgyNykoFHYt0F8b5DZ8mK9GZE.QlQzMfOfUO3";
    extraGroups = [ "wheel" ]; # Enable ‘sudo’ for the user.
    shell = pkgs.zsh;
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
      (ghostty.overrideAttrs (old: {
        buildInputs =
          old.buildInputs
          ++ (with gst_all_1; [
            gstreamer
            gst-plugins-base
            gst-plugins-good
          ]);
        postInstall = (old.postInstall or "") + ''
          rm -f $out/share/nautilus-python/extensions/ghostty.py
        '';
      }))
    ];
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
      charis-sil
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

  networking.firewall.enable = false;

  programs.dconf.profiles.gdm.databases = [
    {
      settings."org/gnome/desktop/interface" = {
        cursor-size = lib.gvariant.mkInt32 28;
        text-scaling-factor = 1.33;
      };
    }
  ];

  environment.sessionVariables = {
    XCOMPOSECACHE = "/tmp/.compose-cache/";
  };

  programs.zsh = {
    enable = true;
    promptInit = ''
      if [[ -n "$IN_NIX_SHELL" ]]; then
        export PS1="%F{green}[nix-shell] →%f "
      else
        export PS1="%F{green}→%f "
      fi
    '';
    interactiveShellInit = ''
      setopt NO_PROMPT_CR
      setopt no_beep
    '';
  };

  programs.nautilus-open-any-terminal = {
    enable = true;
    terminal = "ghostty";
  };

  system.stateVersion = "25.05";
}
