{ lib, pkgs, config, inputs, ... }:
let
  swayAssets = ../../assets/sway;

  swayPkg = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.sway;
  ghosttyPkg = inputs.nixpkgs-unstable.legacyPackages.${pkgs.system}.ghostty;

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
in {
  services.displayManager.ly.enable = true;
  services.displayManager.ly.settings = {
    animation = "doom";
    doom_fire_height = 6;
    doom_fire_spread = 2;
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
      alacritty
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

  environment.etc."sway/config".source = "${swayAssets}/config";
  environment.etc."sway/userchrome.css".source = "${swayAssets}/userchrome.css";

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
