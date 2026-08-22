{ ... }: {
  xdg.configFile."clangd/config.yaml".text = ''
    CompileFlags:
      Add: [-std=c++23]
  '';
}
