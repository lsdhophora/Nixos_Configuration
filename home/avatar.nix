{ lib, ... }:

{
  home.file.".face" = {
    source = ../assets/avatar/face.png;
  };

  home.activation.setAvatar = lib.hm.dag.entryAfter [ "writeBorder" ] ''
    if [ -f "$HOME/.face" ]; then
      dbus-send --system --dest=org.freedesktop.Accounts --type=method_call --print-reply=literal /org/freedesktop/Accounts/User$(id -u) org.freedesktop.Accounts.User.SetIconFile string:$HOME/.face
    fi
  '';
}
