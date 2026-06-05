{ pkgs, ... }:

{
  home.packages = with pkgs; [
    mcp-nixos
  ];

  programs.opencode = {
    enable = true;
    settings = {
      "$schema" = "https://opencode.ai/config.json";
      autoupdate = false;
      default_agent = "plan";
      agent = {
        build.color = "secondary";
        plan.color = "warning";
      };
      mcp = {
        NixOS_everything = {
          type = "local";
          command = [ "mcp-nixos" ];
        };
      };
    };
  };
}
