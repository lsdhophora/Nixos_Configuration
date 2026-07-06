{ pkgs, ... }:

{
  services.kmscon = {
    enable = true;
    hwRender = true;
    term = "xterm-256color";
    extraOptions = "--font-size 20";
    fonts = [
      {
        name = "Maple Mono NF CN";
        package = pkgs.maple-mono.NF-CN-unhinted;
      }
    ];
  };
}
