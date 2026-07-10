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

The ROCm package index used for the PyTorch install targets `gfx103X-dgpu`
(RDNA2, e.g. RX 6000 series) by default - edit `index_url` under `[rocm]` in
`stem-splitter.ini` if you have a different AMD GPU (see the comments in
that file for other targets). Only read the first time `--setup` installs
torch; delete `venv\` and rerun `--setup` to pick up a change.

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

Requires `.\run.ps1 --setup` to have been run first (needs `venv\` and
`tools\ffmpeg.exe`/`ffprobe.exe` - `bundle.bat` doesn't download these
itself, only packages what's already there).

```
.\bundle.bat
```

Uses PyInstaller (`--onedir`) to produce a fully self-contained
`bundle\dist\stem-splitter\` folder - Python, torch/rocm, demucs, yt-dlp,
ffmpeg, and `stem-splitter.ini` all included. Unlike `build.bat`'s launcher,
this folder doesn't need `venv\` to exist afterwards and can be copied
elsewhere. Add `bundle\dist\stem-splitter\` to your `PATH`, then run it from
anywhere:

```
stem-splitter "<YouTube URL>"
```

Since this exe is truly standalone, `video\`/`audio\` output folders are
created under whatever directory you run it from (not the install folder) -
different from `build.bat`'s launcher, which always writes under this
project's own folders.

`bundle\` is gitignored; rerun `bundle.bat` after changing dependencies or
`stem-splitter.ini`. The bundled torch/rocm build is whichever GPU
architecture `venv\` was set up with (`index_url` in `stem-splitter.ini`,
default `gfx103X-dgpu`), so the bundle is only portable to machines with a
matching GPU.

## Bundling a standalone Demucs executable

Requires `.\run.ps1 --setup` to have been run first (needs `venv\` with
torch/demucs installed - `demucs-bundle.bat` doesn't install these itself).

```
.\demucs-bundle.bat
```

Same idea as [stemrollerapp/demucs-cxfreeze](https://github.com/stemrollerapp/demucs-cxfreeze):
uses `cx_Freeze` (not PyInstaller) to freeze just Demucs+torch - not the rest
of this app (yt-dlp, video download, 2-stem mixing) - into a single
`bundle\demucs-cxfreeze\demucs-cxfreeze.exe`. Entry point is
`scripts\run_demucs.py`, so it gets the same soundfile-based WAV/FLAC writer
`main.py` uses (avoids needing torchcodec/ffmpeg-codec DLLs). Behaves like
the demucs CLI:

```
demucs-cxfreeze -n htdemucs_ft -d cuda -o "<outdir>" "<input.wav>"
```

As with the upstream repo, ffmpeg/ffprobe and model files are **not**
bundled - put this project's `tools\` folder on PATH before running it, and
either let Demucs download models on first use or pass `--repo` with a
folder of pre-downloaded ones. `bundle\` is gitignored; rerun
`demucs-bundle.bat` after changing dependencies. Like `bundle.bat`, the
frozen torch build is whichever GPU architecture `venv\` was set up with, so
it's only portable to machines with a matching GPU.

## Building an installer

Requires [Inno Setup](https://jrsoftware.org/isinfo.php)
(`winget install JRSoftware.InnoSetup`) and a `bundle\dist\stem-splitter\`
built via `.\bundle.bat` first.

```
.\installer.bat
```

Produces `installer\output\stem-splitter-rocm-install.exe` - a
wizard installer (no admin rights needed) that lets the user pick a
destination folder, optionally adds it to their `PATH`, and registers a
proper uninstaller in "Apps & Features". `installer\output\` is gitignored;
`installer\stem-splitter.iss` (the Inno Setup script) is tracked.

## CI / releases

Three GitHub Actions workflows, all on `windows-latest` (this project is
Windows-only):

- **[.github/workflows/ci.yml](.github/workflows/ci.yml)** - runs on every
  push/PR. Installs `requirements.txt` (pulling a small stock CPU torch via
  demucs's own dependency, *not* the ~3.6GB ROCm nightly build) and verifies
  `main.py`/`scripts\*.py` import and run cleanly, `stem-splitter.ini` parses,
  and `run.bat`/`build.bat`/`bundle.bat`/`installer.bat`/`demucs-bundle.bat`
  all parse and fail gracefully without a `venv\`. Fast (a couple minutes),
  cheap, no GPU/ROCm needed.
- **[.github/workflows/release.yml](.github/workflows/release.yml)** - runs
  on every published GitHub Release (or manually via "Run workflow", which
  builds but skips the upload step). Does the real, expensive build: `run.bat
  --setup` (downloads the full ROCm/torch build), `bundle.bat`,
  `installer.bat`, then uploads `stem-splitter-rocm-install.exe` to the
  release with `gh release upload`. Takes roughly 30-45 minutes and counts
  2x against your Actions minutes quota (Windows runners). Standard
  GitHub-hosted runners have limited free disk space, which is tight against
  what this build needs (venv + bundle + installer output add up to
  ~9-10GB) - if it starts failing on disk space, a larger or self-hosted
  runner may be needed.
- **[.github/workflows/release-demucs.yml](.github/workflows/release-demucs.yml)** -
  same trigger as `release.yml`, but builds the standalone `demucs-cxfreeze`
  bundle instead: `run.bat --setup`, `demucs-bundle.bat`, zips
  `bundle\demucs-cxfreeze\` into `demucs-cxfreeze-rocm.zip`, and uploads it to
  the release. Independent of `release.yml` (different job, different
  tool - `cx_Freeze` instead of PyInstaller+Inno Setup) so a failure in one
  doesn't block the other. Same disk space caveat as `release.yml`.

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

### Output folder locations

`stem-splitter.ini`, next to `main.py` (or next to `stem-splitter.exe` for
`build.bat`/`bundle.bat`/the installer), controls where `video\` and `audio\`
output go:

```ini
[paths]
audio_dir = %USERPROFILE%\Music\stem-splitter
video_dir = %USERPROFILE%\Videos\stem-splitter
```

Absolute paths are used as-is (`%VAR%` and `~` are expanded); relative paths
are resolved against `stem-splitter.ini`'s own folder. Leave a value blank,
or delete the file, to fall back to the `audio\`/`video\` defaults. Editing
an installed copy's `stem-splitter.ini` directly is safe - reinstalling or
upgrading via the installer won't overwrite an existing one.
