# Impermanence: root on tmpfs, everything durable under /persist.
#
# Layout (bind mounts, zero-displacement staging through /mnt/data):
#   /           = tmpfs       (wiped every boot)
#   /mnt/data   = p2 ext4     (original root partition, content stays put)
#   /nix        = bind /mnt/data/nix       (store + nix db, untouched)
#   /persist    = bind /mnt/data/persist   (all persistent data)
#   /home       = tmpfs       (only home.persistence paths survive, see home/persistence*.nix)
{ ... }:
{
  fileSystems."/" = {
    device = "none";
    fsType = "tmpfs";
    options = [
      "mode=755"
      "size=4G"
    ];
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
  # /home on tmpfs: only the paths declared in home/persistence*.nix
  # (home.persistence."/persist") are bind-mounted from /persist/home/FeiHsueh.
  fileSystems."/home" = {
    device = "tmpfs";
    fsType = "tmpfs";
    options = [
      "mode=755"
      "size=8G"
    ];
    neededForBoot = true;
  };

  environment.persistence."/persist" = {
    directories = [
      # System user/group uid-gid stability across reboots (impermanence warning).
      "/var/lib/nixos"
      "/var/lib/NetworkManager"
      "/etc/NetworkManager/system-connections"
      "/etc/NetworkManager/VPN"
      "/var/lib/zerotier-one"
      "/var/lib/cups"
      "/var/spool/cups"
      "/var/spool/atjobs"
      "/var/spool/atspool"
      "/var/lib/bluetooth"
      "/var/lib/boltd"
      "/var/lib/AccountsService"
      "/var/lib/fprint"
      "/var/lib/fwupd"
      "/var/lib/upower"
      "/var/lib/colord"
      "/var/lib/udisks2"
      "/var/lib/power-profiles-daemon"
      "/var/lib/tlp"
      # Plasma Login Manager greeter config. The Login Screen KCM copies the
      # Plasma settings of the current user to this directory. The greeter
      # reads these files at the next start. The root file system is tmpfs,
      # so the copy is lost without this entry. The owner must be the
      # plasmalogin user, or the greeter cannot write its config.
      {
        directory = "/var/lib/plasmalogin/.config";
        user = "plasmalogin";
        group = "plasmalogin";
        mode = "0750";
      }
      "/var/log/journal"
    ];
    files = [ "/etc/machine-id" ];
  };

  swapDevices = [ { device = "/persist/swapfile"; } ];
}
