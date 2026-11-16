"""Procesa las voces de Control de misión como transmisión de radio espacial.

Entrada: WAV mono generados con la síntesis de voz de Windows (System.Speech,
voz "Microsoft David", inglés). Ver tools/generate_voice_tts.ps1.
Salida: game/assets/audio/voice/<mismo nombre>.wav (p. ej. onb_1_en.wav, dust_es.wav)

Efecto: banda de radio (300-3000 Hz), leve saturación, siseo de portadora,
tonos Quindar al abrir y cerrar (2525 Hz / 2475 Hz, como en las misiones Apollo)
y pequeños cortes de señal.

Uso (necesita numpy; sirve el Python de Blender):
  blender --background --python-exit-code 1 --python tools/generate_voice_radio.py -- <carpeta_wav_crudos>
"""
import os
import sys
import wave

import numpy as np

SR = 22050
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "audio", "voice")


def read_wav(path):
    with wave.open(path, "rb") as w:
        sr = w.getframerate()
        data = np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16).astype(np.float32) / 32768.0
        if w.getnchannels() == 2:
            data = data.reshape(-1, 2).mean(axis=1)
    if sr != SR:
        t_old = np.arange(len(data)) / sr
        t_new = np.arange(int(len(data) * SR / sr)) / SR
        data = np.interp(t_new, t_old, data).astype(np.float32)
    return data


def write_wav(path, data):
    data = np.clip(data, -1.0, 1.0)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes((data * 32767).astype(np.int16).tobytes())


def bandpass(x, lo, hi):
    spec = np.fft.rfft(x)
    f = np.fft.rfftfreq(len(x), 1.0 / SR)
    # flancos suaves (no un corte duro, que suena metálico)
    gain = 1.0 / (1.0 + (lo / np.maximum(f, 1.0)) ** 4) / (1.0 + (f / hi) ** 4)
    return np.fft.irfft(spec * gain, n=len(x)).astype(np.float32)


def tone(freq, dur, amp=0.32):
    t = np.arange(int(dur * SR)) / SR
    env = np.minimum(1.0, np.minimum(t, dur - t) / 0.01)
    return (np.sin(2 * np.pi * freq * t) * env * amp).astype(np.float32)


def process(x, seed):
    rng = np.random.default_rng(seed)
    x = x / (np.max(np.abs(x)) + 1e-6) * 0.8
    x = bandpass(x, 320.0, 3000.0)
    x = np.tanh(x * 2.2) / np.tanh(2.2)  # saturación de radio
    # pequeños desvanecimientos de señal (2-3 por línea)
    env = np.ones_like(x)
    for _ in range(rng.integers(2, 4)):
        c = rng.integers(SR, max(SR + 1, len(x) - SR))
        w = int(SR * rng.uniform(0.04, 0.09))
        env[c:c + w] *= rng.uniform(0.35, 0.6)
    x *= env
    pad = np.zeros(int(0.12 * SR), np.float32)
    body = np.concatenate([pad, x, pad])
    hiss = bandpass(rng.normal(0, 1, len(body)).astype(np.float32), 500.0, 6000.0)
    hiss *= 0.035 / (np.std(hiss) + 1e-6)
    body = body * 0.85 + hiss
    gap = np.zeros(int(0.05 * SR), np.float32)
    out = np.concatenate([tone(2525.0, 0.25), gap, body, gap, tone(2475.0, 0.25)])
    return out / (np.max(np.abs(out)) + 1e-6) * 0.9


def main():
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else sys.argv[1:]
    src = args[0]
    os.makedirs(OUT, exist_ok=True)
    files = sorted(f for f in os.listdir(src) if f.lower().endswith(".wav"))
    for i, f in enumerate(files):
        y = process(read_wav(os.path.join(src, f)), seed=11 + i)
        dst = os.path.join(OUT, f)
        write_wav(dst, y)
        print(dst, "%.1f s" % (len(y) / SR))


main()
