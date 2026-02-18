{ lib, pkgs, ... }:

{
  home.file.".face" = {
    source = ../assets/avatar/face.png;
  };

  home.activation.setAvatar = lib.hm.dag.entryAfter [ "writeBorder" ] ''
    /run/current-system/sw/bin/dbus-send --system --dest=org.freedesktop.Accounts --type=method_call --print-reply=literal /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User.SetIconFile string:$HOME/.face
  '';
}
