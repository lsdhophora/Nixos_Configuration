{ pkgs, ... }:

{
  environment.systemPackages = with pkgs; [
    elvish
    carapace
  ];
}
