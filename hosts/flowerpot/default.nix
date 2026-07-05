{ lib, pkgs, ... }:

{
  imports = [
    ./hardware-configuration.nix
    ../../modules/profiles/core.nix
    ../../modules/profiles/desktop.nix
    ../../modules/profiles/printing.nix
    ../../modules/profiles/proxying.nix
    ../../modules/profiles/kmscon.nix
    ../../modules/desktop/sway.nix
    ../../modules/services/tlp.nix
  ];

  services.logind.settings.Login = {
    HandleLidSwitch = "lock";
    HandleLidSwitchExternalPower = "lock";
    HandleLidSwitchDocked = "lock";
  };

  home-manager.users.lophophora = {
    gtk = {
      enable = true;
      gtk4.theme = null;
      font = {
        name = "IBM Plex Sans 12";
        package = pkgs.ibm-plex;
      };
      theme = {
        name = "adw-gtk3-dark";
        package = pkgs.adw-gtk3;
      };
      iconTheme = {
        name = "Adwaita-purple";
      };
      cursorTheme = {
        name = "Adwaita";
        size = 24;
      };
    };

    dconf.settings."org/gnome/desktop/interface" = {
      "accent-color" = "purple";
      "color-scheme" = "prefer-dark";
      "gtk-theme" = lib.mkForce "adw-gtk3-dark";
      "cursor-theme" = "Adwaita";
      "font-name" = lib.mkForce "IBM Plex Sans 12";
      "document-font-name" = lib.mkForce "IBM Plex Sans 12";
      "monospace-font-name" = lib.mkForce "IBM Plex Mono 12";
    };
    dconf.settings."org/gnome/desktop/wm/preferences" = {
      "button-layout" = "appmenu:";
    };

    home.sessionVariables = {
      GSETTINGS_SCHEMA_DIR = "${pkgs.gsettings-desktop-schemas}/share/gsettings-schemas/${pkgs.gsettings-desktop-schemas.name}/glib-2.0/schemas";
      GTK_USE_PORTAL = "0";
    };

    xdg.configFile."alacritty/alacritty.toml".source =
      ../../assets/sway/alacritty.toml;
    xdg.configFile."sway/toggle-dropdown.sh" = {
      source = ../../assets/sway/toggle-dropdown.sh;
      executable = true;
      force = true;
    };
    xdg.configFile."i3blocks/config".source =
      ../../assets/sway/i3blocks/config;
    xdg.configFile."sway/i3blocks/layout".source =
      ../../assets/sway/i3blocks/layout;
    xdg.configFile."sway/i3blocks/battery".source =
      ../../assets/sway/i3blocks/battery;
    xdg.configFile."sway/i3blocks/brightness".source =
      ../../assets/sway/i3blocks/brightness;
    xdg.configFile."sway/i3blocks/datetime".source =
      ../../assets/sway/i3blocks/datetime;
    xdg.configFile."sway/i3blocks/volume".source =
      ../../assets/sway/i3blocks/volume;
    xdg.configFile."sway/i3blocks/wifi".source =
      ../../assets/sway/i3blocks/wifi;
    xdg.configFile."emacs/lisp/nmcli-wifi.el".source =
      ../../assets/emacs/nmcli-wifi.el;
    xdg.configFile."sway-mimeapps.list".text = ''
      [Default Applications]
      inode/directory=emacs.desktop
      application/pdf=zathura.desktop
    '';

    xdg.configFile."zathura/zathurarc".text = ''
      set completion-bg "#1a1a1a"
      set completion-fg "#cccccc"
      set completion-highlight-bg "#9141ac"
      set completion-highlight-fg "#000000"
      set default-bg "#111111"
      set default-fg "#cccccc"
      set highlight-color "#9141ac"
      set highlight-active-color "#b060d0"
      set inputbar-bg "#1a1a1a"
      set inputbar-fg "#cccccc"
      set notification-bg "#1a1a1a"
      set notification-fg "#cccccc"
      set recolor-lightcolor "#111111"
      set recolor-darkcolor "#cccccc"
      set selection-clipboard clipboard
      set statusbar-bg "#1a1a1a"
      set statusbar-fg "#cccccc"
      set zoom-min 10
    '';

    services.dunst = {
      enable = true;
      settings = {
        global = {
          monitor = 0;
          width = 300;
          offset = "10x50";
          origin = "top-right";
          font = "Adwaita Sans 11";
          corner_radius = 0;
          background = "#1a1a1a";
          foreground = "#cccccc";
          frame_color = "#9141ac";
          separator_color = "#9141ac";
          highlight = "#9141ac";
          timeout = 5;
          icon_theme = "Adwaita-purple";
        };
      };
    };

    xdg.configFile."gtk-3.0/gtk.css".text = ''
      decoration, .titlebar, headerbar, window {
        box-shadow: none;
        border-radius: 0;
      }
      .view:selected, .view:selected:focus,
      row:selected, row:selected:focus,
      flowboxchild:selected, flowboxchild:selected:focus {
        background-color: #9141ac;
      }
      selection {
        background-color: #9141ac;
        color: white;
      }
      button.suggested-action {
        background-color: #9141ac;
        color: white;
      }
      button.suggested-action:hover {
        background-color: #a34ec0;
      }
      button.suggested-action:active {
        background-color: #7d3694;
      }
    '';
    xdg.configFile."gtk-4.0/gtk.css".text = ''
      @define-color accent_color #9141ac;
      @define-color accent_bg_color #9141ac;
      @define-color selected_bg_color alpha(#9141ac, 0.25);
      @define-color selected_fg_color shade(#9141ac, 0.5);
      :root {
        --accent-color: #9141ac;
        --accent-bg-color: #9141ac;
      }
      window, .titlebar, headerbar {
        box-shadow: none;
        border-radius: 0;
      }
      .view:selected, .view:selected:focus,
      row:selected, row:selected:focus,
      flowboxchild:selected, flowboxchild:selected:focus {
        background-color: #9141ac;
      }
      selection {
        background-color: #9141ac;
        color: white;
      }
      entry:focus-within {
        box-shadow: inset 0 0 0 2px #9141ac !important;
        border-color: #9141ac !important;
        outline: 2px solid #9141ac !important;
        outline-offset: -2px !important;
      }
      .accent {
        color: #9141ac;
      }
      button.suggested-action {
        background-color: #9141ac;
        color: white;
      }
      button.suggested-action:hover {
        background-color: #a34ec0;
      }
      button.suggested-action:active {
        background-color: #7d3694;
      }
      button.suggested {
        background-color: #9141ac;
        color: white;
      }
      button.suggested:hover {
        background-color: #a34ec0;
      }
      button.suggested:active {
        background-color: #7d3694;
      }
    '';
  };
}
