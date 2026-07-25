{ ... }:

let
  sw = "/run/current-system/sw/bin";
in
{
  security.sudo.extraConfig = "Defaults pwfeedback";

  security.sudo.extraRules = [
    {
      users = [ "lophophora" ];
      commands = [
        { command = "${sw}/lsblk";      options = [ "NOPASSWD" "SETENV" ]; }
        { command = "${sw}/vgs";        options = [ "NOPASSWD" "SETENV" ]; }
        { command = "${sw}/vgchange";   options = [ "NOPASSWD" "SETENV" ]; }
        { command = "${sw}/vgdisplay";  options = [ "NOPASSWD" "SETENV" ]; }
        { command = "${sw}/cryptsetup"; options = [ "NOPASSWD" "SETENV" ]; }
      ];
    }
  ];
}
