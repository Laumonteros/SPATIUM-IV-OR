"""SPATIUM IV — Síntesis de efectos de sonido (material propio, sin licencias de terceros).

Dirección de sonido: en el exterior lunar no hay aire; lo que el astronauta oye
llega por vibración a través del traje (graves, apagados) o por la radio/electrónica.

Uso (cualquier Python con numpy; p. ej. el de Blender):
  blender -b --factory-startup --python tools/generate_sfx.py -- <raiz_repo>
Salida: game/assets/audio/sfx/*.wav (mono, 44,1 kHz, 16 bits)
"""
import os
import sys
import wave

import numpy as np

SR = 44100
ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else os.getcwd()
OUT = os.path.join(ROOT, "game", "assets", "audio", "sfx")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(42)


def t(sec):
    return np.arange(int(SR * sec)) / SR


def noise(sec):
    return rng.standard_normal(int(SR * sec))


def band(x, lo, hi):
    """Filtro pasa-banda por FFT (lo/hi en Hz; lo=0 -> pasa-bajos)."""
    f = np.fft.rfft(x)
    fr = np.fft.rfftfreq(len(x), 1 / SR)
    m = ((fr >= lo) & (fr <= hi)).astype(float)
    # bordes suaves
    m = np.convolve(m, np.hanning(31) / np.hanning(31).sum(), mode="same")
    return np.fft.irfft(f * m, len(x))


def env(n, attack, decay, sustain=0.0, hold=0.0):
    a = int(SR * attack)
    h = int(SR * hold)
    e = np.zeros(n)
    e[:a] = np.linspace(0, 1, a, endpoint=False) if a else 0
    e[a:a + h] = 1.0
    rest = n - a - h
    if rest > 0:
        e[a + h:] = sustain + (1 - sustain) * np.exp(-np.arange(rest) / (SR * decay))
    return e


def sine(freq, sec, phase=0.0):
    tt = t(sec)
    if np.ndim(freq) == 0:
        return np.sin(2 * np.pi * freq * tt + phase)
    return np.sin(2 * np.pi * np.cumsum(freq) / SR + phase)


def norm(x, peak=0.9):
    m = np.max(np.abs(x))
    return x * (peak / m) if m > 0 else x


def fade(x, fin=0.003, fout=0.01):
    a, b = int(SR * fin), int(SR * fout)
    x = x.copy()
    if a:
        x[:a] *= np.linspace(0, 1, a)
    if b:
        x[-b:] *= np.linspace(1, 0, b)
    return x


def save(name, x, peak=0.9):
    x = fade(norm(x, peak))
    data = (np.clip(x, -1, 1) * 32767).astype("<i2")
    with wave.open(os.path.join(OUT, name), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(data.tobytes())
    print(f"[sfx] {name} {len(x) / SR:.2f}s")


def pad(x, sec):
    out = np.zeros(int(SR * sec))
    out[:min(len(x), len(out))] = x[:len(out)]
    return out


# --- Traje: pasos, salto, aterrizaje (vibración transmitida por el traje) -----
def thud(sec, f0, weight):
    n = int(SR * sec)
    body = sine(np.linspace(f0, f0 * 0.6, n), sec) * env(n, 0.002, sec * 0.18)
    grit = band(noise(sec), 150, 900) * env(n, 0.001, sec * 0.08) * 0.35
    crunch = band(noise(sec), 1200, 3500) * env(n, 0.001, 0.02) * 0.06
    return body * weight + grit + crunch


save("suit_step.wav", thud(0.22, 85, 1.0), 0.7)
save("suit_land.wav", thud(0.45, 70, 1.4) + pad(thud(0.2, 110, 0.5) * 0.5, 0.45), 0.9)
jump = band(noise(0.35), 300, 1600) * env(int(SR * 0.35), 0.03, 0.08) * 0.4 + thud(0.35, 95, 0.6)
save("suit_jump.wav", jump, 0.6)

# --- Respiración en el casco (bucle de 4,2 s) --------------------------------
n = int(SR * 4.2)
br = band(noise(4.2), 250, 2600)
shape = np.zeros(n)
tt = t(4.2)
shape += np.clip(np.sin(np.pi * np.clip(tt / 1.5, 0, 1)), 0, 1) ** 1.6 * 0.8          # inhalar
shape += np.clip(np.sin(np.pi * np.clip((tt - 1.7) / 1.9, 0, 1)), 0, 1) ** 1.3 * 1.0  # exhalar
breath = br * shape + band(noise(4.2), 60, 200) * shape * 0.6
save("suit_breath_loop.wav", breath, 0.5)

# --- Zumbido del soporte vital (bucle de 6 s, ventilador + bomba) -------------
hum = (sine(118, 6) * 0.4 + sine(236, 6) * 0.15 + sine(59, 6) * 0.3) * (1 + 0.05 * sine(0.5, 6))
hum += band(noise(6), 300, 1200) * 0.12
save("suit_hum_loop.wav", hum, 0.35)

# --- Linterna del casco ------------------------------------------------------
def click(sec, f, bright):
    n = int(SR * sec)
    return band(noise(sec), f, f * 3) * env(n, 0.0005, 0.006) + sine(f * bright, sec) * env(n, 0.0005, 0.02) * 0.3


save("light_on.wav", pad(click(0.06, 1800, 1.0), 0.12) + pad(np.zeros(int(SR * 0.03)).tolist() + list(click(0.05, 2400, 1.2) * 0.6), 0.12), 0.6)
save("light_off.wav", pad(click(0.06, 1500, 0.8), 0.1), 0.5)

# --- Recolección --------------------------------------------------------------
n = int(SR * 0.9)
scoop = band(noise(0.9), 500, 2500) * env(n, 0.05, 0.25, hold=0.15) * 0.6
bag = pad(band(noise(0.25), 2000, 6000) * env(int(SR * 0.25), 0.01, 0.06) * 0.4, 0.9)
bag = np.roll(bag, int(SR * 0.55))
save("collect_regolith.wav", scoop + bag + thud(0.9, 90, 0.3), 0.75)

n = int(SR * 1.3)
tinks = np.zeros(n)
for i, (f, d) in enumerate([(2350, 0.0), (3170, 0.09), (2780, 0.19), (4120, 0.33)]):
    s = (sine(f, 1.3) + 0.5 * sine(f * 2.76, 1.3) + 0.25 * sine(f * 5.4, 1.3)) * env(n, 0.001, 0.12)
    tinks += np.roll(s, int(SR * d)) * (0.7 - i * 0.1)
save("collect_crystal.wav", tinks * 0.5 + scoop[:n] * 0.4 if len(scoop) >= n else tinks * 0.5 + pad(scoop, 1.3) * 0.4, 0.7)

n = int(SR * 1.0)
chip = np.zeros(n)
for d in (0.0, 0.18, 0.31):
    chip += np.roll(pad(band(noise(0.08), 900, 4000) * env(int(SR * 0.08), 0.0005, 0.015), 1.0), int(SR * d))
save("collect_rock.wav", chip + thud(1.0, 120, 0.4), 0.75)

# --- Escáner: pulso tipo sonar con ecos ---------------------------------------
n = int(SR * 2.2)
sweep = sine(np.linspace(700, 1500, n), 2.2) * env(n, 0.005, 0.18)
ping = np.zeros(n)
for k, d in enumerate((0.0, 0.32, 0.64, 0.96)):
    ping += np.roll(sweep, int(SR * d)) * (0.85 ** k) * (0.6 if k else 1.0)
ping += band(noise(2.2), 3000, 8000) * env(n, 0.001, 0.03) * 0.15
save("scanner_ping.wav", ping, 0.7)

# --- Interfaz -----------------------------------------------------------------
save("ui_click.wav", pad(sine(1400, 0.05) * env(int(SR * 0.05), 0.001, 0.012), 0.08), 0.45)
save("ui_hover.wav", pad(sine(2200, 0.03) * env(int(SR * 0.03), 0.001, 0.006), 0.05), 0.25)
n = int(SR * 0.5)
chime = (sine(880, 0.5) * env(n, 0.003, 0.15) + np.roll(sine(1318.5, 0.5) * env(n, 0.003, 0.2), int(SR * 0.09)))
save("ui_notify.wav", chime, 0.5)
n = int(SR * 0.6)
deny = sine(np.linspace(420, 300, n), 0.6) * env(n, 0.005, 0.12) + sine(np.linspace(426, 305, n), 0.6) * env(n, 0.005, 0.12)
save("ui_deny.wav", deny, 0.45)
# --- Contador Geiger (bucle de 3 s): clics aleatorios ---------------------------
n = int(SR * 3.0)
g = np.zeros(n)
click = band(noise(0.004), 1500, 9000) * env(int(SR * 0.004), 0.0001, 0.0012)
for pos in rng.integers(0, n - len(click), 70):
    g[pos:pos + len(click)] += click * rng.uniform(0.5, 1.0)
save("geiger_loop.wav", g, 0.6)
print("[sfx] listo")
