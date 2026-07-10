"""Runs demucs.separate, replacing its torchaudio-based WAV/FLAC writer with
soundfile so it works without torchcodec/ffmpeg-codec DLLs being present.

Importable (run(argv)) so main.py can call it in-process - a frozen
PyInstaller build's sys.executable is the app itself, not a generic Python
interpreter, so re-exec'ing this as a subprocess would not work there.
"""
import sys

import soundfile as sf

import demucs.audio as demucs_audio

_SUBTYPES = {
    ("PCM_S", 16): "PCM_16",
    ("PCM_S", 24): "PCM_24",
    ("PCM_S", 32): "PCM_32",
    ("PCM_F", 32): "FLOAT",
    (None, 16): "PCM_16",
    (None, 24): "PCM_24",
    (None, 32): "PCM_32",
}


def _sf_save(uri, src, sample_rate, encoding=None, bits_per_sample=None, **_kwargs):
    subtype = _SUBTYPES.get((encoding, bits_per_sample), "PCM_16")
    data = src.detach().cpu().numpy()
    if data.ndim == 2:
        data = data.T
    sf.write(str(uri), data, sample_rate, subtype=subtype)


demucs_audio.ta.save = _sf_save

from demucs.separate import main as _demucs_main  # noqa: E402


def run(argv: list[str]) -> None:
    _demucs_main(argv)


if __name__ == "__main__":
    run(sys.argv[1:])
