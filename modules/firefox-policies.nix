{ lib, ... }:
# Firefox-family enterprise policies, written to the system locations that
# the browsers read at startup (SysConfD + policies/policies.json):
#
#   /etc/firefox/policies/policies.json    (Firefox; empirically verified)
#   /etc/librewolf/policies/policies.json  (LibreWolf; app-named SysConfD)
#
# The same policy set is shared via lib/firefox-policies.nix.  Writing both
# files is harmless: each browser only reads its own.
let
  policies = import ../lib/firefox-policies.nix { inherit lib; };
  policyFile = {
    text = builtins.toJSON { inherit policies; };
  };
in
{
  environment.etc."firefox/policies/policies.json" = policyFile;
  environment.etc."librewolf/policies/policies.json" = policyFile;
}
