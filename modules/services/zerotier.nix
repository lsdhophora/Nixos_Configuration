{ config, pkgs, ... }:

# ZeroTier P2P mesh VPN.
# The network ID lives in the sops secret "zerotier-network-id".
# The ZeroTier interface is named "zt" + the first 5 chars of the network ID.
let
  ztInterface = "zt16635"; # derived from network ID 166359304e1d85d6 (in sops)
  # Ports of local services reachable from iOS over ZeroTier.
  echoPortsTcp = [ ];
  echoPortsUdp = [ ];
in
{
  services.zerotierone.enable = true;

  # Join the network at boot. The ID comes from the decrypted sops secret.
  # nixpkgs already opens UDP 9993 (the ZeroTier port) automatically.
  systemd.services.zerotier-join = {
    description = "Join ZeroTier network from sops secret";
    # Secrets are placed by the sops activation script before multi-user.target.
    after = [ "zerotierone.service" ];
    requires = [ "zerotierone.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = "${pkgs.bash}/bin/bash -c '${config.services.zerotierone.package}/bin/zerotier-cli join $(cat ${config.sops.secrets.zerotier-network-id.path})'";
    };
  };

  # Expose local services on the ZeroTier interface only.
  networking.firewall.interfaces.${ztInterface} = {
    allowedTCPPorts = echoPortsTcp;
    allowedUDPPorts = echoPortsUdp;
  };
}
