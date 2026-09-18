{
  pkgs,
  inputs,
  ...
}:
{
  home.packages = with pkgs; [
    wl-clipboard
    libnotify
    gh
    lazygit
    at
    nnn
    just
    # Pin the CLI to the flake input revision.
    inputs.home-manager.packages.${pkgs.stdenv.hostPlatform.system}.home-manager
    # Agent multiplexer that lives in the terminal. The pinned nixos-26.05
    # channel has no herdr package, so overlays/herdr.nix takes it from
    # nixpkgs-unstable and patches the client raw-mode ordering.
    herdr
    # Transcribe audio and video. The engine is sherpa-onnx from the binary
    # cache, so no local build happens. The model files go to
    # ~/.local/share/asr/models, which home/persistence.nix keeps.
    asr
  ];
}
