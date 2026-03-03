{
  pkgs,
  ...
}:

{
  security.sudo.extraConfig = "Defaults pwfeedback";
}
