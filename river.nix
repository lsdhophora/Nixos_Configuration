{ config, pkgs, ... }:
{
  wayland.windowManager.river = {
    enable = true;
    settings = {
      border-width = 2;
      input = {
        "pointer-*" = {
          accel-profile = "flat";
          events = true;
          pointer-accel = -0.3;
          tap = false;
        };
      };
      map = {
        normal = {
          "Alt Q" = "close";
          "Super Return" = "spawn foot";
          "Super D" = "spawn fuzzel";
          "Super J" = "focus-view next";
          "Super K" = "focus-view previous";
          "Super Shift+J" = "swap next";
          "Super Shift+K" = "swap previous";
          "Super Space" = "zoom";
          "Super F" = "toggle-fullscreen";
          "Super Shift+Space" = "toggle-float";
          "Super 1" = "set-focused-tags 1";
          "Super 2" = "set-focused-tags 2";
          "Super 3" = "set-focused-tags 4";
          "Super 4" = "set-focused-tags 8";
          "Super 5" = "set-focused-tags 16";
          "Super 6" = "set-focused-tags 32";
          "Super 7" = "set-focused-tags 64";
          "Super 8" = "set-focused-tags 128";
          "Super 9" = "set-focused-tags 256";
          "Super Shift+1" = "set-view-tags 1";
          "Super Shift+2" = "set-view-tags 2";
          "Super Shift+3" = "set-view-tags 4";
          "Super Shift+4" = "set-view-tags 8";
          "Super Shift+5" = "set-view-tags 16";
          "Super Shift+6" = "set-view-tags 32";
          "Super Shift+7" = "set-view-tags 64";
          "Super Shift+8" = "set-view-tags 128";
          "Super Shift+9" = "set-view-tags 256";
          "Super Shift+E" = "exit";
          "Super L" = "spawn swaylock";
          "None XF86MonBrightnessDown" = "spawn 'brightnessctl set 5%-'";
          "None XF86MonBrightnessUp" = "spawn 'brightnessctl set +5%'";
        };
      };
      set-cursor-warp = "on-output-change";
      set-repeat = "50 300";
      spawn = [
        "waybar"
      ];
      xcursor-theme = "Adwaita 24";
    };
    extraConfig = ''
      riverctl background-color 0x002b36
      riverctl border-color-focused 0x93a1a1
      riverctl border-color-unfocused 0x586e75
      riverctl default-layout rivertile
      rivertile -view-padding 5 -outer-padding 5
    '';
  };

  programs.waybar.enable = true;
  programs.swaylock.enable = true;
  programs.swayidle = {
    enable = true;
    timeouts = [
      {
        timeout = 300;
        command = "${pkgs.swaylock}/bin/swaylock -fF";
      }
      {
        timeout = 600;
        command = "${pkgs.wlopm}/bin/wlopm --off \\*";
        resumeCommand = "${pkgs.wlopm}/bin/wlopm --on \\*";
      }
      {
        timeout = 900;
        command = "systemctl suspend";
      }
    ];
  };
  home.packages = [
    pkgs.brightnessctl
    pkgs.wlopm
  ];
}
