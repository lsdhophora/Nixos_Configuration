{ lib, pkgs, ... }:

{
  home.activation.setAvatar = lib.hm.dag.entryAfter [ "writeBorder" ] ''
    ${pkgs.dbus}/bin/dbus-send --system --dest=org.freedesktop.Accounts --type=method_call --print-reply=literal /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User.SetIconFile string:/home/lophophora/.config/nixos/assets/avatar/face.png
  '';
}
