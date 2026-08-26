{ ... }:

{
  # pwfeedback: show asterisks while typing the password.
  # lecture=never: suppress the first-use sudo lecture banner.
  security.sudo.extraConfig = ''
    Defaults pwfeedback
    Defaults lecture=never
  '';
}
