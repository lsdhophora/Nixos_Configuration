{ lib, pkgs, ... }: {
  gtk = {
    enable = true;
    gtk4.theme = null;
    font = {
      name = "IBM Plex Sans";
      size = 14;
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
    "document-font-name" = lib.mkForce "IBM Plex Sans 14";
    "monospace-font-name" = lib.mkForce "IBM Plex Mono 14";
  };

  dconf.settings."org/gnome/desktop/wm/preferences" = {
    "button-layout" = "appmenu:";
  };

  xdg.configFile."gtk-3.0/gtk.css".text = ''
    @define-color accent_bg_color #9141ac;
    @define-color accent_fg_color white;
    @define-color accent_color #9141ac;
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
}
