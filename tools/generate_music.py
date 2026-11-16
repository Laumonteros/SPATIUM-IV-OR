"""SPATIUM IV — Música ambiental y sonidos de la nave (síntesis propia, sin licencias de terceros).

Estilo: ambiental "amigable": colchones suaves (pads) en modo lidio, campanitas
lejanas y un eco largo. Nada de percusión: acompaña la exploración sin invadir.

Uso: blender -b --factory-startup --python tools/generate_music.py -- <raiz_repo>
Salida: game/assets/audio/music/*.wav, game/assets/audio/sfx/ship_*.wav
"""
import os
import sys
import wave

import numpy as np

SR = 32000
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else os.getcwd()
MUSIC = os.path.join(ROOT, "game", "assets", "audio", "music")
SFX = os.path.join(ROOT, "game", "assets", "audio", "sfx")
os.makedirs(MUSIC, exist_ok=True)
rng = np.random.default_rng(7)


def note(n):
    """Número MIDI -> Hz."""
    return 440.0 * 2 ** ((n - 69) / 12)


def tt(sec):
    return np.arange(int(SR * sec)) / SR


def pad_voice(freq, sec, detune=0.004, bright=0.25):
    t = tt(sec)
    out = np.zeros_like(t)
    for d in (-detune, 0.0, detune):
        f = freq * (1 + d)
        out += np.sin(2 * np.pi * f * t) + bright * np.sin(2 * np.pi * 2 * f * t) * 0.5 + bright * 0.2 * np.sin(2 * np.pi * 3 * f * t)
    return out / 3.0


def envelope(n, attack, release):
    e = np.ones(n)
    a, r = int(SR * attack), int(SR * release)
    e[:a] = np.sin(np.linspace(0, np.pi / 2, a)) ** 2
    e[-r:] = np.cos(np.linspace(0, np.pi / 2, r)) ** 2
    return e


def bell(freq, sec):
    t = tt(sec)
    s = sum(a * np.sin(2 * np.pi * freq * m * t) * np.exp(-t * dcy) for m, a, dcy in ((1, 1.0, 1.6), (2.76, 0.4, 2.5), (5.4, 0.15, 4.0)))
    return s * np.minimum(1.0, t * 200)


def echo(x, delay, fb, mix, taps=6):
    y = x.copy()
    d = int(SR * delay)
    g = 1.0
    for k in range(1, taps + 1):
        g *= fb
        if d * k >= len(x):
            break
        y[d * k:] += x[:-d * k] * g * mix
    return y


def lowpass(x, cutoff):
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    f *= 1.0 / (1.0 + (fr / cutoff) ** 4)
    return np.fft.irfft(f, len(x))


def save(path, x, peak=0.8, stereo_width=0.0):
    x = x / (np.max(np.abs(x)) + 1e-9) * peak
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"[music] {os.path.basename(path)} {len(x) / SR:.1f}s")


def loopable(x, fade=3.0):
    """Cruza el final con el principio para que el bucle no tenga corte."""
    n = int(SR * fade)
    head = x[:n].copy()
    tail = x[-n:].copy()
    w = np.linspace(0, 1, n)
    x = x[:-n].copy()
    x[:n] = head * w + tail * (1 - w)
    return x


# --- Exploración: progresión lenta en D lidio (D - E/D - Bm7 - Gmaj7) ---------
CHORDS = [[50, 57, 62, 66, 69], [52, 59, 64, 68, 71], [47, 54, 59, 62, 66], [43, 50, 55, 59, 66]]
CH_LEN = 12.0
total = CH_LEN * len(CHORDS) * 2
mix = np.zeros(int(SR * (total + 6)))
for i in range(len(CHORDS) * 2):
    ch = CHORDS[i % len(CHORDS)]
    start = int(SR * i * CH_LEN)
    seg = sum(pad_voice(note(n), CH_LEN + 5, bright=0.18) * (0.9 if n < 55 else 0.55) for n in ch)
    seg *= envelope(len(seg), 3.5, 4.5)
    mix[start:start + len(seg)] += seg
# Campanitas pentatónicas dispersas
penta = [74, 76, 78, 81, 83, 86]
for k in range(26):
    pos = rng.uniform(2, total - 6)
    b = bell(note(int(rng.choice(penta))), 5.0) * rng.uniform(0.25, 0.5)
    s = int(SR * pos)
    mix[s:s + len(b)] += b
mix = lowpass(mix, 3800)
mix = echo(mix, 0.55, 0.55, 0.45)
mix = loopable(mix[:int(SR * total) + int(SR * 3)], 3.0)
save(os.path.join(MUSIC, "exploration_loop.wav"), mix, 0.55)

# --- Intro: crecimiento lento + tema de campanas -----------------------------
dur = 46.0
intro = np.zeros(int(SR * dur))
seq = [(0, [38, 45, 50]), (10, [38, 45, 52, 57]), (20, [43, 50, 55, 59, 66]), (30, [45, 52, 57, 61, 64]), (38, [50, 57, 62, 66, 69])]
for i, (t0, ch) in enumerate(seq):
    end = seq[i + 1][0] + 4 if i + 1 < len(seq) else dur
    l = end - t0
    seg = sum(pad_voice(note(n), l, bright=0.15 + 0.05 * i) for n in ch) * (0.4 + 0.15 * i)
    seg *= envelope(len(seg), 3.0, 3.0)
    s = int(SR * t0)
    intro[s:s + len(seg)] += seg[:len(intro) - s]
melody = [(22, 74), (24, 78), (26, 81), (29, 83), (31, 81), (34, 78), (38, 86), (40, 85), (42, 81)]
for t0, n in melody:
    b = bell(note(n), 5.0) * 0.6
    s = int(SR * t0)
    intro[s:s + len(b)] += b[:len(intro) - s]
intro = lowpass(intro, 4200)
intro = echo(intro, 0.5, 0.5, 0.4)
intro *= envelope(len(intro), 2.0, 4.0)
save(os.path.join(MUSIC, "intro_theme.wav"), intro, 0.7)

# --- Nave: motor (rugido grave en bucle) y toque de motores de maniobra ------
n = int(SR * 4.0)
noise = rng.standard_normal(n)
rumble = lowpass(noise, 180) * 3.0 + lowpass(noise, 900) * 0.4
rumble += np.sin(2 * np.pi * 42 * tt(4.0)) * 0.5 + np.sin(2 * np.pi * 63 * tt(4.0)) * 0.25
rumble *= 1 + 0.15 * np.sin(2 * np.pi * 7 * tt(4.0))
save(os.path.join(SFX, "ship_engine_loop.wav"), loopable(rumble, 0.5), 0.8)
n = int(SR * 0.6)
puff = lowpass(rng.standard_normal(n), 1200) * np.exp(-np.arange(n) / (SR * 0.12))
save(os.path.join(SFX, "ship_thruster.wav"), puff, 0.6)
# Rover: zumbido eléctrico de motores en bucle
r = np.sin(2 * np.pi * 220 * tt(2.0)) * 0.3 + np.sin(2 * np.pi * 440 * tt(2.0)) * 0.08 + lowpass(rng.standard_normal(int(SR * 2.0)), 600) * 0.6
save(os.path.join(SFX, "rover_motor_loop.wav"), loopable(r, 0.3), 0.5)
print("[music] listo")
