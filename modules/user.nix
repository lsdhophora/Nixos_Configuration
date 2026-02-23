{
  pkgs,
  inputs,
  config,
  ...
}:

{
  users.users.lophophora = {
    isNormalUser = true;
    description = "费雪";
    hashedPasswordFile = config.age.secrets.hashedPassword.path;
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

  environment.systemPackages = with pkgs; [
    nano
    git
    wget
    inputs.agenix.packages.${pkgs.stdenv.hostPlatform.system}.default
  ];

  system.stateVersion = "25.05";
}
