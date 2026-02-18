{
  pkgs,
  inputs,
  ...
}:

{
  users.users.lophophora = {
    isNormalUser = true;
    description = "费雪";
    hashedPassword = "$y$j9T$ywlcAEMJIDVX/1G5Pm5bi1$YSb/zJEgyNykoFHYt0F8b5DZ8mK9GZE.QlQzMfOfUO3";
    extraGroups = [ "wheel" ];
    shell = pkgs.zsh;
    packages = with pkgs; [
      tree
      ffmpeg
      fastfetch
      imagemagick
      (texlive.combine {
        inherit (texlive)
          scheme-basic
          ctex
          chinese-jfm
          fontspec
          luatex
          luacode
          graphics
          geometry
          fancyhdr
          titlesec
          hyphen-greek
          hyperref
          postnotes
          eso-pic
          footmisc
          polyglossia
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
    ];
  };

  systemd.user.services.set-avatar = {
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "oneshot";
      ExecStart = "${pkgs.dbus}/bin/dbus-send --system --dest=org.freedesktop.Accounts --type=method_call --print-reply=literal /org/freedesktop/Accounts/User$(id -u lophophora) org.freedesktop.Accounts.User.SetIconFile string:/home/lophophora/.face";
    };
  };

  environment.systemPackages = with pkgs; [
    nano
    git
    wget
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  system.stateVersion = "25.05";
}
