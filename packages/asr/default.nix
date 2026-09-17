# Transcribe a local audio or video file with sherpa-onnx and SenseVoice.
#
# sherpa-onnx comes from nixpkgs and hits the binary cache, so no local
# build is needed and no pip environment is installed. The driver holds
# the pipeline: ffmpeg, silence cuts and recognition.
#
# The ONNX model files stay out of the store. The driver downloads them
# on the first run to ~/.local/share/asr/models, which home/persistence.nix
# keeps across a reboot. That avoids a 230 MB store path and a second
# copy of a large binary blob.
{
  lib,
  stdenv,
  python3,
  makeWrapper,
  cacert,
  sherpa-onnx,
  ffmpeg,
}:

stdenv.mkDerivation {
  pname = "asr";
  version = "1.0.0";

  dontUnpack = true;
  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    install -Dm644 ${./asr.py} $out/libexec/asr.py
    makeWrapper ${lib.getExe python3} $out/bin/asr \
      --add-flags $out/libexec/asr.py \
      --set-default SSL_CERT_FILE ${cacert}/etc/ssl/certs/ca-bundle.crt \
      --prefix PATH : ${
        lib.makeBinPath [
          sherpa-onnx
          ffmpeg
        ]
      }
    runHook postInstall
  '';

  meta = {
    description = "Transcribe local audio and video with sherpa-onnx and SenseVoice";
    mainProgram = "asr";
    license = lib.licenses.mit;
  };
}
