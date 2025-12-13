{ config, pkgs, ... }:

{
  # System-level configuration (in configuration.nix)
  # security.polkit.enable = true;
  xdg.portal = {
    enable = true;
    extraPortals = [
      pkgs.xdg-desktop-portal-wlr
      pkgs.xdg-desktop-portal-gtk
    ];
  };
  # User-level Home Manager configuration
  home.packages = [
    pkgs.soteria # Polkit authentication agent
    pkgs.wmenu # Assuming wmenu-run is from wmenu package
    pkgs.swaylock # For screen locking
    pkgs.swayidle # For idle management (optional)
    pkgs.waybar # For status bar (optional but common)
    pkgs.grim # Screenshot tool
    pkgs.slurp # Region selector for screenshots
    pkgs.wl-clipboard # Clipboard manager for Wayland
  ];

  wayland.windowManager.sway = {
    enable = true;
    wrapperFeatures.gtk = true; # For GTK theme support

    config = {
      modifier = "Mod4";
      menu = "wmenu-run";

      keybindings =
        let
          mod = config.wayland.windowManager.sway.config.modifier;
        in
        pkgs.lib.mkOptionDefault {
          "${mod}+Shift+space" = "floating toggle";
          "${mod}+d" = "exec $menu";

          # Focus movement (vim-like keys)
          "${mod}+h" = "focus left";
          "${mod}+j" = "focus down";
          "${mod}+k" = "focus up";
          "${mod}+l" = "focus right";

          # Move windows
          "${mod}+Shift+h" = "move left";
          "${mod}+Shift+j" = "move down";
          "${mod}+Shift+k" = "move up";
          "${mod}+Shift+l" = "move right";

          # Workspace switching
          "${mod}+1" = "workspace number 1";
          "${mod}+2" = "workspace number 2";
          "${mod}+3" = "workspace number 3";
          "${mod}+4" = "workspace number 4";
          "${mod}+5" = "workspace number 5";
          "${mod}+6" = "workspace number 6";
          "${mod}+7" = "workspace number 7";
          "${mod}+8" = "workspace number 8";
          "${mod}+9" = "workspace number 9";
          "${mod}+0" = "workspace number 10";

          # Move focused window to workspace
          "${mod}+Shift+1" = "move container to workspace number 1";
          "${mod}+Shift+2" = "move container to workspace number 2";
          "${mod}+Shift+3" = "move container to workspace number 3";
          "${mod}+Shift+4" = "move container to workspace number 4";
          "${mod}+Shift+5" = "move container to workspace number 5";
          "${mod}+Shift+6" = "move container to workspace number 6";
          "${mod}+Shift+7" = "move container to workspace number 7";
          "${mod}+Shift+8" = "move container to workspace number 8";
          "${mod}+Shift+9" = "move container to workspace number 9";
          "${mod}+Shift+0" = "move container to workspace number 10";

          # Layout toggles
          "${mod}+s" = "layout stacking";
          "${mod}+w" = "layout tabbed";
          "${mod}+e" = "layout toggle split";

          # Fullscreen
          "${mod}+f" = "fullscreen toggle";

          # Reload and exit
          "${mod}+Shift+c" = "reload";
          "${mod}+Shift+e" = "exec swaymsg exit";

          # Scratchpad
          "${mod}+Shift+minus" = "move scratchpad";
          "${mod}+minus" = "scratchpad show";

          # Resize mode
          "${mod}+r" = "mode \"resize\"";

          # Lock screen
          "${mod}+Shift+l" = "exec swaylock";

          # Screenshots
          "Print" = "exec grim -g \"$(slurp)\" - | wl-copy"; # Full screenshot to clipboard
          "${mod}+Print" = "exec grim - | wl-copy"; # Select region to clipboard
        };

      input = {
        "type:touchpad" = {
          tap = "enabled";
          tap_button_map = "lrm"; # 1-finger = left, 2-finger = right, 3-finger = middle
          dwt = "enabled"; # Disable while typing
          dwtp = "enabled"; # Disable while trackpoint is in use
          natural_scroll = "enabled";
          scroll_factor = "0.8";
          middle_emulation = "enabled";
        };
      };

      modes = {
        resize = {
          "h" = "resize shrink width 10 px";
          "j" = "resize grow height 10 px";
          "k" = "resize shrink height 10 px";
          "l" = "resize grow width 10 px";
          "Return" = "mode \"default\"";
          "Escape" = "mode \"default\"";
        };
      };

      window = {
        commands = [
          {
            criteria = {
              class = ".*";
            };
            command = "title_format \"%title\"";
          }
          {
            criteria = {
              class = ".*";
              app_id = ".*";
            };
            command = "border normal 1";
          }
        ];
      };

      bars = [
        {
          position = "top";
          command = "${pkgs.waybar}/bin/waybar";
        }
      ];

      startup = [
        # Example startup commands
        {
          command = "systemctl --user import-environment";
          always = true;
        }
        {
          command = "dbus-update-activation-environment --systemd WAYLAND_DISPLAY XDG_CURRENT_DESKTOP=sway";
        }
      ];
    };

    extraConfig = ''
      # Idle configuration (optional)
      exec swayidle -w timeout 300 'swaylock -f' \
                   timeout 600 'swaymsg "output * dpms off"' \
                   resume 'swaymsg "output * dpms on"' \
                   before-sleep 'swaylock -f'

      # Default workspace
      default_border pixel 1
      gaps inner 5
      smart_gaps on
    '';
  };

  # Systemd service for Soteria Polkit agent
  systemd.user.services.polkit-soteria = {
    description = "Soteria Polkit Authentication Agent";
    wantedBy = [ "graphical-session.target" ];
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    serviceConfig = {
      Type = "simple";
      ExecStart = "${pkgs.soteria}/bin/soteria";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
    };
  };

  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    x11 = {
      enable = true;
      defaultCursor = "Adwaita";
    };
  };

  # GTK configuration to disable rounded corners
  gtk = {
    enable = true;
    gtk3.extraCss = ''
      window {
        border-radius: 0;
      }
    '';
    gtk4.extraCss = ''
      window {
        border-radius: 0;
      }
    '';
  };

  # Configures MPV in Home-Manager with full FFmpeg, removes umpv artifacts, and disables OSC window controls.
  programs.mpv = {
    enable = true;

    package =
      pkgs.mpv-with-scripts
        {
          mpv = pkgs.mpv-unwrapped.override { ffmpeg = pkgs.ffmpeg-full; };
        }
        .overrideAttrs
        (old: {
          postFixup = (old.postFixup or "") + ''
            rm -f $out/bin/umpv
            rm -f $out/share/applications/umpv.desktop
            rm -f $out/share/icons/hicolor/*/apps/umpv.png
          '';

          passthru.providedPrograms = [
            "mpv"
            "mpv_identify.sh"
          ];
        });

    scriptOpts = {
      osc.windowcontrols = "no";
    };
  };

}
