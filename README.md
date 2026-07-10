# stem-splitter

Download a YouTube video, extract its audio, and split it into stems
(vocals, drums, bass, other, plus a vocals/instrumental 2-stem mix) using
[Demucs](https://github.com/facebookresearch/demucs).
Built for Windows with an AMD GPU (ROCm).

## What it does

Given a YouTube URL, `run.ps1` (or `run.bat`) will:

1. Download the best-quality video+audio with `yt-dlp` into `video\<title>\`.
2. Extract the audio track to a 24-bit WAV with `ffmpeg` into `audio\<title>\`.
3. Run Demucs (`htdemucs_ft` model) on the WAV to separate it into 4 stems
   (vocals, drums, bass, other), saved to `audio\<title>\stems\`.
4. Derive a vocals/instrumental 2-stem mix from those 4 stems (instrumental
   is drums+bass+other summed) - no second Demucs pass needed - saved to
   `audio\<title>\stems\2stem\`.

## Requirements

- Windows with an AMD GPU (uses ROCm nightly builds of PyTorch).
- Python 3.12.

## Setup

```
.\run.ps1 --setup
```

This creates a virtual environment in `venv\`, installs PyTorch/torchaudio/torchvision
with ROCm support, installs the packages in `requirements.txt` (`yt-dlp`, `demucs`,
`soundfile`), and downloads a portable `ffmpeg`/`ffprobe` into `tools\`.

## Usage

```
.\run.ps1 "<YouTube URL>"
```

> Run from PowerShell, use `run.ps1`, not `run.bat`. Calling `run.bat`
> directly from PowerShell can silently truncate URLs at any `=`, `&`, `,`,
> or `;` character (a quirk of how cmd.exe tokenizes batch-file arguments),
> which breaks most YouTube URLs. `run.ps1` avoids this by invoking the venv's
> Python directly. `run.bat` still works fine from `cmd.exe`.

Output layout for a video titled `My Song`:

```
video\My Song\My Song.mkv                             - downloaded video
audio\My Song\My Song.wav                             - extracted audio
audio\My Song\stems\htdemucs_ft\My Song\vocals.wav     - 4-stem split
audio\My Song\stems\htdemucs_ft\My Song\drums.wav
audio\My Song\stems\htdemucs_ft\My Song\bass.wav
audio\My Song\stems\htdemucs_ft\My Song\other.wav
audio\My Song\stems\2stem\vocals.wav                   - 2-stem split
audio\My Song\stems\2stem\instrumental.wav
```

## Building a PATH executable

```
.\build.bat
```

Compiles `build\stem-splitter.exe`, a thin launcher that forwards straight to
this project's `venv\Scripts\python.exe` and `main.py` (the venv itself is
never copied - run `.\run.ps1 --setup` first if you haven't). Add `build\` to
your `PATH`, then run it from anywhere:

```
stem-splitter "<YouTube URL>"
```

`build\` is gitignored; rerun `build.bat` after moving the project folder.
Since this launcher just forwards to the project's own `main.py`, output still
always goes under this project's `video\`/`audio\` folders, no matter which
directory you run `stem-splitter` from.

## Bundling a redistributable executable

```
.\bundle.bat
```

Uses PyInstaller (`--onedir`) to produce a fully self-contained
`bundle\dist\stem-splitter\` folder - Python, torch/rocm, demucs, yt-dlp, and
ffmpeg all included. Unlike `build.bat`'s launcher, this folder doesn't need
`venv\` to exist afterwards and can be copied elsewhere. Add
`bundle\dist\stem-splitter\` to your `PATH`, then run it from anywhere:

```
stem-splitter "<YouTube URL>"
```

Since this exe is truly standalone, `video\`/`audio\` output folders are
created under whatever directory you run it from (not the install folder) -
different from `build.bat`'s launcher, which always writes under this
project's own folders.

`bundle\` is gitignored; rerun `bundle.bat` after changing dependencies.
The bundled torch/rocm build is pinned to a specific AMD GPU architecture
(`gfx103X-dgpu`, see `requirements.txt`), so the bundle is only portable to
machines with a matching GPU.

## Building an installer

Requires [Inno Setup](https://jrsoftware.org/isinfo.php)
(`winget install JRSoftware.InnoSetup`) and a `bundle\dist\stem-splitter\`
built via `.\bundle.bat` first.

```
.\installer.bat
```

Produces `installer\output\stem-splitter-amd-rocm-gfx1030-install.exe` - a
wizard installer (no admin rights needed) that lets the user pick a
destination folder, optionally adds it to their `PATH`, and registers a
proper uninstaller in "Apps & Features". `installer\output\` is gitignored;
`installer\stem-splitter.iss` (the Inno Setup script) is tracked.

## Cleaning up

```
.\run.ps1 --clean
```

Removes downloaded/generated files under `audio\`, `tools\`, and `video\`
(keeps `ffmpeg.exe`/`ffprobe.exe` and `.gitkeep` placeholders).

## Configuration

Demucs settings can be tweaked at the top of `main.py`:

- `DEMUCS_MODEL` - model name (default `htdemucs_ft`)
- `DEMUCS_SHIFTS` - number of random shifts for prediction averaging (default `2`)
- `DEMUCS_OVERLAP` - overlap between prediction windows (default `0.5`)
