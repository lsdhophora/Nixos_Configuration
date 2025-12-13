{ config, pkgs, ... }:

{
  services.xserver = {
    enable = true;

    # 1. Enable Startx
    displayManager.startx.enable = true;

    # 2. Configure DWM and directly override source code
    windowManager.dwm = {
      enable = true;
      package = pkgs.dwm.overrideAttrs (oldAttrs: {
        src = ./dwm; # Your local dwm source code directory
      });
    };

    # 3. Startup script: Set environment variables and start slstatus
    # Note: Since slstatus is already included in systemPackages, you can run the command directly here
    displayManager.sessionCommands = ''
      # Fcitx5 Environment variable configuration
      export GTK_IM_MODULE=fcitx
      export QT_IM_MODULE=fcitx
      export XMODIFIERS=@im=fcitx

      # Restore monitor settings (Optional)
      # ${pkgs.xorg.xrandr}/bin/xrandr --auto &

      # Start slstatus (run in background)
      slstatus &
    '';
  };

  # 4. Fcitx5 Input Method configuration
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

    # Local Slstatus: Directly Override in the list, note the required parentheses
    (pkgs.slstatus.overrideAttrs (oldAttrs: {
      src = ./slstatus; # Your local slstatus source code directory
    }))

    (pkgs.st.overrideAttrs (oldAttrs: {
      src = ./st; # Your local st source code directory
    }))

  ];
}
