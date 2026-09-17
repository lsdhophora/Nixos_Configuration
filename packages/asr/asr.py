#!/usr/bin/env python3
"""Transcribe a local audio or video file with sherpa-onnx and SenseVoice.

The steps are: convert the input to 16 kHz mono, cut it at silence, and
recognise each part with the SenseVoice model. One model covers zh, en,
yue, ja and ko, so a mixed recording needs no extra setup.
"""

import argparse
import json
import os
import re
import shutil
import subprocess
import sys
import tarfile
import tempfile
import urllib.request
from pathlib import Path

SAMPLE_RATE = 16000
MODEL_REPO = "sherpa-onnx-sense-voice-zh-en-ja-ko-yue-2024-07-17"
MODEL_FILES = ("model.int8.onnx", "tokens.txt")
HF_BASE = f"https://huggingface.co/csukuangfj/{MODEL_REPO}/resolve/main"
# hf-mirror answers where huggingface.co is blocked.
MODEL_MIRRORS = (HF_BASE, f"https://hf-mirror.com/csukuangfj/{MODEL_REPO}/resolve/main")
GH_URL = (
  "https://github.com/k2-fsa/sherpa-onnx/releases/download/asr-models/"
  f"{MODEL_REPO}.tar.bz2"
)

# A cut lands on the first silence in this window, so a word stays whole.
CHUNK_SECONDS = 30.0
MIN_CHUNK_SECONDS = 12.0
SILENCE_DB = -40
SILENCE_MIN_SECONDS = 0.3
SILENCE_START_RE = re.compile(r"silence_start: (-?[0-9.]+)")
SILENCE_END_RE = re.compile(r"silence_end: (-?[0-9.]+)")
SENTENCE_END = ".!?"


def run(cmd: list[str]) -> tuple[str, str]:
  """Run a command. Return stdout and stderr, and stop on a bad status."""
  result = subprocess.run(cmd, capture_output=True, text=True)
  if result.returncode != 0:
    sys.stderr.write(result.stderr[-2000:])
    raise SystemExit(f"command failed with status {result.returncode}: {cmd[0]}")
  return result.stdout, result.stderr


def stamp(seconds: float) -> str:
  """Format seconds as H:MM:SS for a transcript line."""
  total = max(0, int(seconds))
  hours, rest = divmod(total, 3600)
  minutes, secs = divmod(rest, 60)
  return f"{hours:d}:{minutes:02d}:{secs:02d}"


def download(url: str, dest: Path) -> None:
  """Download a URL to a file and show the progress at 10 percent steps.

  A partial file stays out of the way, so a broken download is not
  mistaken for a finished one.
  """
  part = dest.with_name(dest.name + ".part")
  with urllib.request.urlopen(url, timeout=60) as response:
    total = int(response.headers.get("content-length") or 0)
    done = 0
    step = -1
    with open(part, "wb") as out:
      while True:
        block = response.read(1 << 20)
        if not block:
          break
        out.write(block)
        done += len(block)
        if total > 0 and (done * 10 // total > step or done == total):
          step = done * 10 // total
          sys.stderr.write(f"\r  {done * 100 // total:3d}%  {done / 1e6:6.1f} / {total / 1e6:6.1f} MB")
          sys.stderr.flush()
  sys.stderr.write("\n")
  part.replace(dest)


def fetch_file(name: str, models: Path) -> None:
  """Download one model file from the first mirror that answers."""
  for base in MODEL_MIRRORS:
    try:
      download(f"{base}/{name}", models / name)
      return
    except Exception as exc:  # noqa: BLE001 - try the next source
      print(f"  {base} failed: {exc}", file=sys.stderr)
  print("  no mirror answered, use the GitHub release archive", file=sys.stderr)
  fetch_archive(models)


def fetch_archive(models: Path) -> None:
  """Download the release archive and take the model files out of it."""
  archive = models / "model.tar.bz2"
  download(GH_URL, archive)
  with tarfile.open(archive, "r:bz2") as tar:
    for name in MODEL_FILES:
      member = tar.getmember(f"{MODEL_REPO}/{name}")
      member.name = name
      tar.extract(member, models, filter="data")
  archive.unlink()


def ensure_models(models: Path) -> None:
  """Download the SenseVoice model files when they are absent.

  The mirrors hold single files. The GitHub release holds one large
  archive, so it is the last fallback.
  """
  missing = [name for name in MODEL_FILES if not (models / name).exists()]
  if not missing:
    return
  models.mkdir(parents=True, exist_ok=True)
  print(f"fetch {MODEL_REPO} into {models}", file=sys.stderr)
  for name in missing:
    fetch_file(name, models)
  for name in MODEL_FILES:
    if not (models / name).exists():
      raise SystemExit(f"model file is still missing: {models / name}")


def audio_format(path: Path) -> tuple[int, int]:
  """Return the sample rate and the channel count of the first audio stream."""
  out, _ = run([
    "ffprobe", "-v", "error", "-select_streams", "a:0",
    "-show_entries", "stream=sample_rate,channels", "-of", "json", str(path),
  ])
  stream = json.loads(out)["streams"][0]
  return int(stream["sample_rate"]), int(stream["channels"])


def to_wav(source: Path, dest: Path) -> None:
  """Write a 16 kHz mono wav file, unless the input is already one."""
  if source.suffix == ".wav":
    rate, channels = audio_format(source)
    if rate == SAMPLE_RATE and channels == 1:
      shutil.copyfile(source, dest)
      return
  run([
    "ffmpeg", "-v", "error", "-y", "-i", str(source),
    "-ac", "1", "-ar", str(SAMPLE_RATE), "-c:a", "pcm_s16le", str(dest),
  ])


def duration_of(path: Path) -> float:
  """Return the duration of a file in seconds."""
  out, _ = run([
    "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "json", str(path),
  ])
  return float(json.loads(out)["format"]["duration"])


def silence_spans(wav: Path, total: float) -> list[tuple[float, float]]:
  """Return the [start, end] pair of each silence in the wav file."""
  _, err = run([
    "ffmpeg", "-v", "info", "-i", str(wav),
    "-af", f"silencedetect=n={SILENCE_DB}dB:d={SILENCE_MIN_SECONDS}",
    "-f", "null", "-",
  ])
  starts = [float(value) for value in SILENCE_START_RE.findall(err)]
  stops = [float(value) for value in SILENCE_END_RE.findall(err)]
  spans = list(zip(starts, stops))
  if len(starts) > len(stops):
    # A silence at the end of the file has no end record.
    spans.append((starts[-1], total))
  return spans


def cut_points(total: float, spans: list[tuple[float, float]]) -> list[tuple[float, float]]:
  """Return the [begin, end] pairs of the parts to recognise.

  A part holds CHUNK_SECONDS at most. The cut lands in the middle of the
  longest silence in the search window, so a word stays whole. A window
  without silence forces a hard cut.
  """
  parts: list[tuple[float, float]] = []
  begin = 0.0
  while total - begin > CHUNK_SECONDS:
    window_end = begin + CHUNK_SECONDS + 5.0
    best: tuple[float, float] | None = None
    for start, stop in spans:
      low = max(start, begin + MIN_CHUNK_SECONDS)
      high = min(stop, window_end)
      if high <= low:
        continue
      if best is None or high - low > best[1] - best[0]:
        best = (low, high)
    end = sum(best) / 2 if best else begin + CHUNK_SECONDS
    parts.append((begin, end))
    begin = end
  parts.append((begin, total))
  return parts


def cut(wav: Path, begin: float, end: float, dest: Path) -> None:
  """Write one part of the wav file to a new file."""
  run([
    "ffmpeg", "-v", "error", "-y", "-ss", f"{begin:.3f}", "-t", f"{end - begin:.3f}",
    "-i", str(wav), "-c:a", "pcm_s16le", str(dest),
  ])


def recognize(wav: Path, models: Path, language: str, threads: int) -> dict:
  """Recognise one wav file and return the sherpa-onnx result object."""
  out, _ = run([
    "sherpa-onnx-offline",
    f"--tokens={models / 'tokens.txt'}",
    f"--sense-voice-model={models / 'model.int8.onnx'}",
    f"--sense-voice-language={language}",
    "--sense-voice-use-itn=true",
    f"--num-threads={threads}",
    str(wav),
  ])
  for line in reversed(out.splitlines()):
    if line.strip().startswith("{"):
      return json.loads(line)
  raise SystemExit("sherpa-onnx-offline returned no result")


def sentences(result: dict) -> list[tuple[float, str]]:
  """Split a result into (start second, text) pairs.

  The token timestamps break the text at the sentence end marks, which
  gives a timestamp for each sentence instead of each part.
  """
  tokens = result.get("tokens") or []
  times = result.get("timestamps") or []
  if not tokens or len(tokens) != len(times):
    return [(0.0, result.get("text", "").strip())]
  out: list[tuple[float, str]] = []
  buffer: list[str] = []
  first = 0.0
  for token, time in zip(tokens, times):
    if not buffer:
      first = time
    buffer.append(token)
    if token.strip().endswith(tuple(SENTENCE_END)):
      out.append((first, "".join(buffer).strip()))
      buffer = []
  if buffer:
    out.append((first, "".join(buffer).strip()))
  return out


def parse_args(argv: list[str]) -> argparse.Namespace:
  default_models = os.environ.get("ASR_MODELS") or str(Path.home() / ".local/share/asr/models")
  parser = argparse.ArgumentParser(prog="asr", description=__doc__)
  parser.add_argument("source", nargs="?", help="local audio or video file")
  parser.add_argument("--models", default=default_models, help="directory of the model files")
  parser.add_argument("--out", default=".", help="directory for the transcript files")
  parser.add_argument("--name", default="", help="base name of the transcript files")
  parser.add_argument("--language", default="auto", choices=["auto", "zh", "en", "yue", "ja", "ko"])
  parser.add_argument("--threads", type=int, default=max(2, (os.cpu_count() or 4) - 2))
  parser.add_argument("--fetch-models", action="store_true", help="download the models and stop")
  parser.add_argument("--keep-temp", action="store_true", help="keep the temporary files")
  return parser.parse_args(argv)


def main(argv: list[str]) -> int:
  args = parse_args(argv)
  models = Path(args.models).expanduser()

  if args.fetch_models:
    ensure_models(models)
    return 0
  if not args.source:
    raise SystemExit("give a media file")
  media = Path(args.source).expanduser().resolve()
  if not media.is_file():
    raise SystemExit(f"no such file: {media}")

  ensure_models(models)

  for tool in ("ffmpeg", "ffprobe", "sherpa-onnx-offline"):
    if not shutil.which(tool):
      raise SystemExit(f"{tool} is not on PATH")

  workdir = Path(tempfile.mkdtemp(prefix="asr-"))
  try:
    print(f"media: {media.name}", file=sys.stderr)
    wav = workdir / "audio16k.wav"
    to_wav(media, wav)
    total = duration_of(wav)

    parts = cut_points(total, silence_spans(wav, total))
    print(f"audio {stamp(total)} in {len(parts)} parts", file=sys.stderr)

    out_dir = Path(args.out).expanduser()
    out_dir.mkdir(parents=True, exist_ok=True)
    name = args.name or media.stem

    lines: list[dict] = []
    for index, (begin, end) in enumerate(parts, 1):
      part = workdir / f"part{index:04d}.wav"
      cut(wav, begin, end, part)
      result = recognize(part, models, args.language, args.threads)
      for time, text in sentences(result):
        if text:
          lines.append({"beg": round(begin + time, 2), "end": round(end, 2), "text": text})
      print(f"  part {index}/{len(parts)} {stamp(begin)} {result.get('text', '')[:50]}", file=sys.stderr)
      part.unlink()

    (out_dir / f"{name}.txt").write_text(
      "".join(f"[{stamp(line['beg'])}] {line['text']}\n" for line in lines), encoding="utf-8")
    (out_dir / f"{name}.jsonl").write_text(
      "".join(json.dumps(line, ensure_ascii=False) + "\n" for line in lines), encoding="utf-8")
    print(f"wrote {out_dir / name}.txt and {out_dir / name}.jsonl", file=sys.stderr)
  finally:
    if args.keep_temp:
      print(f"temporary files: {workdir}", file=sys.stderr)
    else:
      shutil.rmtree(workdir, ignore_errors=True)
  return 0


if __name__ == "__main__":
  sys.exit(main(sys.argv[1:]))
