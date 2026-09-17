# The ASR tool. The engine is sherpa-onnx from nixpkgs, which is in the
# binary cache, so the package installs no compiler and no pip tree.
# packages/asr/asr.py holds the pipeline, see that file for the model
# download location.
final: prev: {
  asr = import ../packages/asr {
    inherit (final)
      lib
      stdenv
      python3
      makeWrapper
      cacert
      sherpa-onnx
      ffmpeg
      ;
  };
}
