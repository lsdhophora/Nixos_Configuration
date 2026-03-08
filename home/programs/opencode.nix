{ pkgs, ... }:

{
  home.packages = [ pkgs.mcp-nixos ];

  programs.mcp.servers.nixos = {
    enable = true;
    command = "mcp-nixos";
  };

  programs.opencode = {
    enable = true;
    settings = {
      "$schema" = "https://opencode.ai/config.json";
      mcp = {
        mcp_everything = {
          type = "local";
          command = [ "mcp-nixos" ];
        };
      };
    };
  };

}
