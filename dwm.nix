{ config, pkgs, ... }:

{
  services.xserver = {
    enable = true;

    # Enable Startx
    displayManager.startx.enable = true;

    # Configure DWM and directly override source code
    windowManager.dwm = {
      enable = true;
      package = pkgs.dwm.overrideAttrs (oldAttrs: {
        src = ./dwm;
      });
    };

    # Startup script: Set environment variables and start slstatus
    displayManager.sessionCommands = ''
      # Fcitx5 Environment variable configuration
      export GTK_IM_MODULE=fcitx
      export QT_IM_MODULE=fcitx
      export XMODIFIERS=@im=fcitx

      # Restore monitor settings
      ${pkgs.xorg.xrandr}/bin/xrandr --auto &

      # Start slstatus (run in background)
      slstatus &
    '';
  };

  # Fcitx5 Input Method configuration
  i18n.inputMethod = {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      fcitx5-gtk
      fcitx5-chinese-addons
      libsForQt5.fcitx5-qt
      kdePackages.fcitx5-with-addons
    ];
  };

  # 5. System software installation
  environment.systemPackages = with pkgs; [
    # dmenu from the official repository
    dmenu

    # Screenshot tool
    scrot

    (pkgs.slstatus.overrideAttrs (oldAttrs: {
      src = ./slstatus;
    }))

    (pkgs.st.overrideAttrs (oldAttrs: {
      src = ./st;
    }))

    xorg.xrandr
  ];
}
