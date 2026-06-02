{ pkgs, ... }:

{
  home.packages = with pkgs; [
    cataclysm-dda
    shattered-pixel-dungeon
    tome4
  ];
}
