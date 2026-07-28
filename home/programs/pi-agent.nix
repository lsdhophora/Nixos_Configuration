{ pkgs, ... }:

{
  home.packages = with pkgs; [ pi-coding-agent ];

  home.file.".pi/agent/settings.json" = {
    text = builtins.toJSON {
      defaultProvider = "deepseek";
      defaultModel = "deepseek-chat";
    };
  };
}
