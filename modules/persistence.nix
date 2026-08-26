# Impermanence: root on tmpfs, everything durable under /persist.
#
# Layout (bind mounts, zero-displacement staging through /mnt/data):
#   /           = tmpfs       (wiped every boot)
#   /mnt/data   = p2 ext4     (original root partition, content stays put)
#   /nix        = bind /mnt/data/nix       (store + nix db, untouched)
#   /persist    = bind /mnt/data/persist   (all persistent data)
#   /home       = bind /persist/home       (whole home persisted)
{ ... }:
{
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [ "mode=755" "size=4G" ];
  };
  fileSystems."/mnt/data" = {
    device = "/dev/disk/by-uuid/f008a750-0a3e-4fcc-a18e-ca7d6e3daa75";
    fsType = "ext4";
    options = [ "noatime" ];
    neededForBoot = true;
  };
  fileSystems."/nix" = {
    device = "/mnt/data/nix";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };
  fileSystems."/persist" = {
    device = "/mnt/data/persist";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };
  fileSystems."/home" = {
    device = "/persist/home";
    fsType = "none";
    options = [ "bind" ];
    neededForBoot = true;
  };

  environment.persistence."/persist" = {
    directories = [
      "/var/lib/NetworkManager" "/etc/NetworkManager/system-connections" "/etc/NetworkManager/VPN"
      "/var/lib/zerotier-one" "/var/lib/cups" "/var/spool/cups"
      "/var/spool/atjobs" "/var/spool/atspool" "/var/lib/bluetooth" "/var/lib/boltd"
      "/var/lib/AccountsService" "/var/lib/fprint" "/var/lib/fwupd" "/var/lib/upower"
      "/var/lib/colord" "/var/lib/udisks2" "/var/lib/power-profiles-daemon" "/var/lib/tlp"
      "/var/log/journal"
    ];
    files = [ "/etc/machine-id" ];
  };

  swapDevices = [ { device = "/persist/swapfile"; } ];
}
