{ lib, pkgs, config, inputs, ... }:
let
  swayAssets = ../../assets/sway;

  swayPkg = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.sway;

  adwPurple = pkgs.runCommand "Adwaita-purple-icon-theme" { } ''
    mkdir -p $out/share/icons
    ln -s ${../../assets/icons/Adwaita-purple} $out/share/icons/Adwaita-purple
  '';
  swayI3blocks = pkgs.runCommand "sway-i3blocks" { } ''
    mkdir -p $out/bin
    for f in ${swayAssets}/i3blocks/*; do
      name=$(basename "$f")
      if [ "$name" != "config" ]; then
        cp "$f" "$out/bin/$name"
        chmod +x "$out/bin/$name"
      fi
    done
  '';

  pantheonPolkit = pkgs.runCommand "pantheon-polkit-wrapper" { } ''
    mkdir -p $out/bin
    ln -s ${pkgs.pantheon.pantheon-agent-polkit}/libexec/policykit-1-pantheon/io.elementary.desktop.agent-polkit \
      $out/bin/pantheon-agent-polkit
  '';

  # ---- Sway config sections ----

  swayVariables = ''
    set $mod Mod4
    set $left h
    set $down j
    set $up k
    set $right l
    set $term kitty
    set $menu wmenu-run -f "IBM Plex Sans 12" -N \#323232 -n \#cccccc -M \#9141ac -m \#cccccc -S \#9141ac -s \#000000
  '';

  swayStartup = ''
    exec pantheon-agent-polkit
    output * bg ~/.config/sway/wallpaper.png fill
    exec fcitx5 -d
    exec ~/.config/sway/mpv-border.sh
    exec ~/.config/sway/low-battery-notify.sh
  '';

  swayInput = ''
    input type:touchpad {
      tap enabled
    }
    seat * hide_cursor 3000
    seat * xcursor_theme Adwaita 24
  '';

  swayIdle = ''
    exec swayidle -w \
      timeout 300 'playerctl status 2>/dev/null | grep -q Playing || swaylock -f -c 000000' \
      timeout 600 'playerctl status 2>/dev/null | grep -q Playing || swaymsg "output * power off"' resume 'swaymsg "output * power on"' \
      before-sleep 'swaylock -f -c 000000'
  '';

  swayAppearance = ''
    gaps inner 5
    gaps horizontal -5
    gaps vertical 5
    font pango:Adwaita Sans Medium 11

    client.focused          #9141ac #9141ac #ffffff #9141ac #9141ac
    client.focused_inactive #333333 #5f676a #888888 #484e50 #5f676a
    client.unfocused        #333333 #222222 #888888 #292d2e #222222
    client.urgent           #2f343a #900000 #ffffff #900000 #900000
  '';

  swayWindowRules = ''
    default_border pixel 2
    default_floating_border pixel 2
    hide_edge_borders smart_no_gaps

    for_window [app_id="(?i)emacs"] border normal 2
    for_window [app_id="mpv"] border pixel 2
    for_window [app_id="swayimg"] border pixel 2
    for_window [app_id="firefox"] border pixel 2
    for_window [title="Authentication Required"] floating enabled, border pixel 2, move position center
    for_window [app_id="kitty"] border pixel 2, focus
    for_window [app_id="kitty-dropdown"] floating enabled, border pixel 2, move position center, sticky enable
    for_window [title="Open File"] floating enabled, border pixel 2, focus
    for_window [app_id="xdg-desktop-portal-gtk"] border pixel 3
  '';

  swayKeybindings = ''
    bindsym $mod+Return exec $term
    bindsym $mod+Shift+q kill
    bindsym $mod+d exec $menu
    bindsym $mod+Shift+x exec swaylock -f -c 000000
    bindsym $mod+Shift+c reload
    bindsym $mod+Shift+e exec swaymsg exit
    floating_modifier $mod normal

    bindsym $mod+$left focus left
    bindsym $mod+$down focus down
    bindsym $mod+$up focus up
    bindsym $mod+$right focus right
    bindsym $mod+Left focus left
    bindsym $mod+Down focus down
    bindsym $mod+Up focus up
    bindsym $mod+Right focus right

    bindsym $mod+Shift+$left move left
    bindsym $mod+Shift+$down move down
    bindsym $mod+Shift+$up move up
    bindsym $mod+Shift+$right move right
    bindsym $mod+Shift+Left move left
    bindsym $mod+Shift+Down move down
    bindsym $mod+Shift+Up move up
    bindsym $mod+Shift+Right move right

    bindsym $mod+1 workspace number 1
    bindsym $mod+2 workspace number 2
    bindsym $mod+3 workspace number 3
    bindsym $mod+4 workspace number 4
    bindsym $mod+5 workspace number 5
    bindsym $mod+6 workspace number 6
    bindsym $mod+7 workspace number 7
    bindsym $mod+8 workspace number 8
    bindsym $mod+9 workspace number 9
    bindsym $mod+0 workspace number 10

    bindsym $mod+Shift+1 move container to workspace number 1
    bindsym $mod+Shift+2 move container to workspace number 2
    bindsym $mod+Shift+3 move container to workspace number 3
    bindsym $mod+Shift+4 move container to workspace number 4
    bindsym $mod+Shift+5 move container to workspace number 5
    bindsym $mod+Shift+6 move container to workspace number 6
    bindsym $mod+Shift+7 move container to workspace number 7
    bindsym $mod+Shift+8 move container to workspace number 8
    bindsym $mod+Shift+9 move container to workspace number 9
    bindsym $mod+Shift+0 move container to workspace number 10

    bindsym $mod+b splith
    bindsym $mod+v splitv
    bindsym $mod+s layout stacking
    bindsym $mod+w layout tabbed
    bindsym $mod+e layout toggle split
    bindsym $mod+f fullscreen
    bindsym Ctrl+Shift+space exec "fcitx5-remote -t; pkill -RTMIN+10 i3blocks"
    bindsym $mod+space focus mode_toggle
    bindsym $mod+Shift+space floating toggle
    bindsym $mod+a focus parent
    bindsym $mod+Shift+a focus child
    bindsym $mod+Shift+minus move scratchpad
    bindsym $mod+minus scratchpad show

    mode "resize" {
      bindsym $left resize shrink width 10px
      bindsym $down resize grow height 10px
      bindsym $up resize shrink height 10px
      bindsym $right resize grow width 10px
      bindsym Left resize shrink width 10px
      bindsym Down resize grow height 10px
      bindsym Up resize shrink height 10px
      bindsym Right resize grow width 10px
      bindsym Return mode "default"
      bindsym Escape mode "default"
    }
    bindsym $mod+r mode "resize"

    bindsym --locked XF86AudioMute exec wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle
    bindsym --locked XF86AudioLowerVolume exec wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-
    bindsym --locked XF86AudioRaiseVolume exec wpctl set-volume --limit 1.0 @DEFAULT_AUDIO_SINK@ 5%+
    bindsym --locked XF86AudioMicMute exec wpctl set-mute @DEFAULT_SOURCE@ toggle
    bindsym --locked XF86AudioPlay exec playerctl play-pause
    bindsym --locked XF86AudioPause exec playerctl play-pause
    bindsym --locked XF86AudioPrev exec playerctl previous
    bindsym --locked XF86AudioNext exec playerctl next
    bindsym --locked XF86AudioStop exec playerctl stop
    bindsym --locked XF86MonBrightnessDown exec brightnessctl set 5%-
    bindsym --locked XF86MonBrightnessUp exec brightnessctl set 5%+

    bindsym Print exec sh -c 'f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png && mkdir -p ~/Pictures/Screenshots && grim "$f" && notify-send "Screenshot" "$(basename "$f") (Fullscreen)"'
    bindsym Shift+Print exec sh -c 'f=~/Pictures/Screenshots/$(date +%Y-%m-%d_%H-%M-%S).png && mkdir -p ~/Pictures/Screenshots && grim -g "$(slurp)" "$f" && notify-send "Screenshot" "$(basename "$f") (Region)"'

    bindsym $mod+grave exec ~/.config/sway/toggle-dropdown.sh
  '';

  swayBar = ''
    bar {
      position top
      tray_output none
      status_command i3blocks
      colors {
        statusline #ffffff
        background #1a1a1a
        binding_mode #000000 #9141ac #ffffff
        focused_workspace #9141ac #9141ac #2d0a2e
        inactive_workspace #323232 #323232 #888888
        urgent_workspace #2f343a #900000 #000000
      }
    }
  '';
in {
  services.displayManager.ly.enable = true;
  services.displayManager.ly.settings = {
    animation = "gameoflife";
    hide_borders = true;
    hide_key_hints = true;
    hide_version_string = true;
    initial_info_text = "";
    session_log = "/tmp/ly-session.log";
  };

  services.accounts-daemon.enable = true;

  programs.sway = {
    enable = true;
    package = swayPkg;
    wrapperFeatures.gtk = true;
    extraSessionCommands = ''
      export XCURSOR_THEME=Adwaita
      export XCURSOR_SIZE=24
    '';
    extraPackages = with pkgs; [
      wmenu
      i3blocks
      brightnessctl
      grim
      playerctl
      slurp
      swayidle
      libnotify
      swaylock
      swaybg
      jq
      wl-clipboard
      pantheonPolkit
      dunst
      zathura
    ];
  };

  environment.etc."sway/config".text = ''
    # Variables
    ${swayVariables}

    # Startup
    ${swayStartup}

    # Input / Seat
    ${swayInput}

    # Idle
    ${swayIdle}

    # Appearance
    ${swayAppearance}

    # Borders & Window Rules
    ${swayWindowRules}

    # Keybindings
    ${swayKeybindings}

    # Status Bar
    ${swayBar}

    include /etc/sway/config.d/*
  '';

  i18n.inputMethod = lib.mkForce {
    enable = true;
    type = "fcitx5";
    fcitx5.addons = with pkgs; [
      kdePackages.fcitx5-chinese-addons
      fcitx5-gtk
    ];
    fcitx5.waylandFrontend = true;
  };

  xdg.portal = {
    enable = true;
    extraPortals = with pkgs; [
      xdg-desktop-portal-gnome
      xdg-desktop-portal-gtk
    ];
    config = lib.mkForce {
      common = {
        default = [ "gtk" ];
        "org.freedesktop.impl.portal.Settings" = [ "gnome" ];
      };
    };
  };

  environment.systemPackages = with pkgs; [
    swayI3blocks
    adw-gtk3
    glib.bin
    adwPurple
    adwaita-icon-theme
    adwaita-fonts
  ];
}
