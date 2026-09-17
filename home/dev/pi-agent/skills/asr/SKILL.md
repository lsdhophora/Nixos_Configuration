---
name: asr
description: Transcribes a local audio or video file to text with the FunASR SenseVoice model on the sherpa-onnx runtime. Covers Chinese, English, Cantonese, Japanese and Korean. Use when the user asks for a transcript, a video script, subtitle text, or a summary of a media file on disk.
keywords: [asr, transcribe, transcription, speech to text, subtitle, 转写, 转录, 文稿, 字幕, 语音识别]
requires_tools: [bash]
---

# ASR (speech to text)

`asr` writes a transcript for a local media file. The engine is
sherpa-onnx with the SenseVoice model, so one model covers Chinese,
English, Cantonese, Japanese and Korean. The command reads the audio
track of the file.

## Usage

    asr <file> [--out DIR] [--name NAME] [--language auto]

| Option | Effect |
| --- | --- |
| `--out DIR` | directory of the output files (default: current directory) |
| `--name NAME` | base name of the output files (default: the file name) |
| `--language` | force `zh`, `en`, `yue`, `ja` or `ko` (default: `auto`) |
| `--threads N` | CPU thread count (default: core count minus two) |
| `--fetch-models` | download the model files and stop |
| `--keep-temp` | keep the temporary wav parts |

The command writes two files:

| File | Content |
| --- | --- |
| `NAME.txt` | one line per sentence, with a `[H:MM:SS]` marker |
| `NAME.jsonl` | `{"beg", "end", "text"}` per sentence, in seconds |

## Procedure

1. Run `asr <file>` in the directory that must hold the output.
2. Read `NAME.txt` and write the summary or the answer.
3. Report the language of the audio track. A re-upload can carry the
   original soundtrack while the page text is translated.

## Notes

- The command reads local files only. For a URL, download the audio
  first, for example with `nix run nixpkgs#yt-dlp -f bestaudio <url>`.
- The model files live in `~/.local/share/asr/models` and survive a
  reboot. The first run downloads about 230 MB when the directory is empty.
- The command cuts the audio at silence before recognition, so a long
  recording does not need a full-length pass.
- Plan about four minutes of CPU time for 30 minutes of audio.
- A cut can fall inside a word when the speaker does not pause.
- The transcript holds the speech, not the page text. Check proper nouns
  against the source: a rare name often comes out wrong.
