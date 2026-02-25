{ pkgs, ... }:

{
  programs.uv.enable = true;

  programs.mcp.servers.nixos = {
    command = "uvx";
    args = [ "mcp-nixos" ];
  };

  programs.opencode = {
    enable = true;
    enableMcpIntegration = true;
  };
}
