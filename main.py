import os
import re
import subprocess
import sys
from pathlib import Path

import numpy as np
import soundfile as sf
import yt_dlp

ROOT = Path(__file__).resolve().parent
VIDEO_DIR = ROOT / "video"
AUDIO_DIR = ROOT / "audio"
TOOLS_DIR = ROOT / "tools"
SCRIPTS_DIR = ROOT / "scripts"
FFMPEG = TOOLS_DIR / "ffmpeg.exe"

DEMUCS_MODEL = "htdemucs_ft"
DEMUCS_SHIFTS = "2"
DEMUCS_OVERLAP = "0.5"


def sanitize(name: str) -> str:
    name = re.sub(r'[\\/:*?"<>|]', "", name).strip().rstrip(".")
    return name[:150] or "video"


def download_video(url: str, title: str) -> Path:
    video_subdir = VIDEO_DIR / title
    video_subdir.mkdir(parents=True, exist_ok=True)

    ydl_opts = {
        "format": "bestvideo+bestaudio/best",
        "merge_output_format": "mkv",
        "outtmpl": str(video_subdir / f"{title}.%(ext)s"),
        "ffmpeg_location": str(TOOLS_DIR),
        "socket_timeout": 30,
        "retries": 20,
        "fragment_retries": 20,
    }
    with yt_dlp.YoutubeDL(ydl_opts) as ydl:
        ydl.download([url])

    files = sorted(video_subdir.glob(f"{title}.*"))
    if not files:
        raise RuntimeError(f"No downloaded file found in {video_subdir}")
    return files[0]


def extract_audio(video_file: Path, title: str) -> Path:
    audio_subdir = AUDIO_DIR / title
    audio_subdir.mkdir(parents=True, exist_ok=True)
    wav_path = audio_subdir / f"{title}.wav"

    subprocess.run(
        [
            str(FFMPEG),
            "-y",
            "-i", str(video_file),
            "-vn",
            "-acodec", "pcm_s24le",
            str(wav_path),
        ],
        check=True,
    )
    return wav_path


def separate_stems(wav_path: Path, title: str) -> None:
    stems_dir = AUDIO_DIR / title / "stems"
    env = os.environ.copy()
    env["PATH"] = str(TOOLS_DIR) + os.pathsep + env.get("PATH", "")
    subprocess.run(
        [
            sys.executable, str(SCRIPTS_DIR / "run_demucs.py"),
            "-n", DEMUCS_MODEL,
            "-d", "cuda",
            "--shifts", DEMUCS_SHIFTS,
            "--overlap", DEMUCS_OVERLAP,
            "--float32",
            "-o", str(stems_dir),
            str(wav_path),
        ],
        check=True,
        env=env,
    )


def create_two_stem_mix(stems_dir: Path, title: str) -> None:
    """Derives a vocals/instrumental (2-stem) split from the 4-stem output,
    instead of running demucs a second time with --two-stems."""
    four_stem_dir = stems_dir / DEMUCS_MODEL / title
    two_stem_dir = stems_dir / "2stem"
    two_stem_dir.mkdir(parents=True, exist_ok=True)

    vocals, sr = sf.read(four_stem_dir / "vocals.wav")
    instrumental = None
    for stem in ("drums", "bass", "other"):
        data, _ = sf.read(four_stem_dir / f"{stem}.wav")
        instrumental = data if instrumental is None else instrumental + data
    instrumental = np.clip(instrumental, -1.0, 1.0)

    sf.write(two_stem_dir / "vocals.wav", vocals, sr, subtype="PCM_24")
    sf.write(two_stem_dir / "instrumental.wav", instrumental, sr, subtype="PCM_24")


def main() -> None:
    if len(sys.argv) != 2:
        print('Usage: python main.py "<YouTube URL>"')
        sys.exit(1)

    url = sys.argv[1]

    print(f"[1/5] Fetching video info: {url}")
    with yt_dlp.YoutubeDL({"quiet": True, "skip_download": True}) as ydl:
        info = ydl.extract_info(url, download=False)
    title = sanitize(info.get("title", "video"))
    print(f"      Title: {title}")

    print("[2/5] Downloading best quality video+audio...")
    video_file = download_video(url, title)
    print(f"      Saved to: {video_file}")

    print("[3/5] Extracting audio (wav)...")
    wav_path = extract_audio(video_file, title)
    print(f"      Saved to: {wav_path}")

    print(f"[4/5] Separating stems with demucs ({DEMUCS_MODEL})...")
    stems_dir = AUDIO_DIR / title / "stems"
    separate_stems(wav_path, title)
    print(f"      Stems saved under: {stems_dir}")

    print("[5/5] Deriving vocals/instrumental (2-stem) mix...")
    create_two_stem_mix(stems_dir, title)
    print(f"      2-stem mix saved under: {stems_dir / '2stem'}")

    print("Done.")


if __name__ == "__main__":
    main()
