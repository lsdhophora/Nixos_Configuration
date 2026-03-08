{ lib, ... }:

{
  services.flatpak.enable = lib.mkDefault true;
}
