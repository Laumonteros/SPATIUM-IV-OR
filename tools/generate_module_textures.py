"""Texturas procedurales de los módulos de la colonia (sin recursos externos).

Genera en game/assets/textures/modules/ (1024 px, repetibles):
  hull_alb.png / hull_nrm.png      revestimiento: paneles de 1 x 0,5 m (textura = 2 m),
                                   juntas hundidas, remaches, manchas y polvo lunar.
  floor_alb.png / floor_nrm.png    chapa antideslizante (diamante) con placas de 1 m (textura = 2 m).
  slab_alb.png / slab_nrm.png      losa de regolito sinterizado (textura = 4 m).
El albedo es casi blanco: se multiplica por el color de cada material.
Normales en convención OpenGL (Y+), la que usa Godot.

Uso (numpy de Blender):
  blender --background --python-exit-code 1 --python tools/generate_module_textures.py
"""
import os
import zlib
import struct

import numpy as np

S = 1024
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "game", "assets", "textures", "modules")
rng = np.random.default_rng(7)


def save_png(path, img):
    img = np.clip(img, 0.0, 1.0)
    data = (img * 255 + 0.5).astype(np.uint8)
    h, w, c = data.shape
    raw = b"".join(b"\x00" + data[y].tobytes() for y in range(h))
    color_type = 2 if c == 3 else 6

    def chunk(tag, payload):
        return struct.pack(">I", len(payload)) + tag + payload + struct.pack(">I", zlib.crc32(tag + payload) & 0xFFFFFFFF)

    png = b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, color_type, 0, 0, 0))
    png += chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")
    with open(path, "wb") as f:
        f.write(png)
    print(path)


def tile_noise(octaves, base=4, persistence=0.55):
    """Ruido de valor repetible (suma de octavas)."""
    out = np.zeros((S, S), np.float32)
    amp, total = 1.0, 0.0
    for o in range(octaves):
        n = base * (2 ** o)
        grid = rng.random((n, n)).astype(np.float32)
        # interpolación bicúbica suave y repetible
        x = np.linspace(0, n, S, endpoint=False)
        i0 = np.floor(x).astype(int)
        t = x - i0
        t = t * t * (3 - 2 * t)
        i1 = (i0 + 1) % n
        rows = grid[i0][:, i0] * (1 - t)[None, :] + grid[i0][:, i1] * t[None, :]
        rows2 = grid[i1][:, i0] * (1 - t)[None, :] + grid[i1][:, i1] * t[None, :]
        layer = rows * (1 - t)[:, None] + rows2 * t[:, None]
        out += layer * amp
        total += amp
        amp *= persistence
    return out / total


def normal_from_height(h, strength):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * 0.5 * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * 0.5 * strength
    n = np.stack([-dx, dy, np.ones_like(h)], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n * 0.5 + 0.5


def blur(a, r):
    for _ in range(r):
        a = (a + np.roll(a, 1, 0) + np.roll(a, -1, 0) + np.roll(a, 1, 1) + np.roll(a, -1, 1)) / 5.0
    return a


yy, xx = np.mgrid[0:S, 0:S].astype(np.float32)


def hull():
    pw, ph = S // 2, S // 4  # paneles de 1 m x 0,5 m
    # desplazamiento de filas alternas (como chapas superpuestas)
    row = (yy // ph).astype(int)
    xs = (xx + (row % 2) * (pw // 2)) % S
    dx = np.minimum(xs % pw, pw - xs % pw)
    dy = np.minimum(yy % ph, ph - yy % ph)
    d = np.minimum(dx, dy)
    seam = np.clip(1.0 - d / 3.0, 0, 1)
    height = -seam * 1.0
    # remaches a 14 px del borde, cada 64 px
    rx = (xs % pw)
    ry = (yy % ph)
    near_x = np.minimum(np.abs(rx - 14), np.abs(rx - (pw - 14)))
    cy_mod = np.abs(((ry - 32) % 64) - 0)
    cy_mod = np.minimum(cy_mod, 64 - cy_mod)
    r = np.sqrt(near_x ** 2 + cy_mod ** 2)
    riv = np.clip(1.0 - r / 4.0, 0, 1) ** 0.6
    height += riv * 0.6
    # variación por panel (tono) y manchas
    pid = (row * 7 + (xs // pw).astype(int) * 13) % 11
    tone = 0.94 + (pid / 10.0 - 0.5) * 0.05
    grime = tile_noise(6, base=4)
    streak = blur(rng.random((S, S)).astype(np.float32), 2)
    streak = np.repeat(streak.mean(axis=0, keepdims=True), S, 0)  # chorreado vertical
    alb = tone - (grime - 0.5) * 0.10 - seam * 0.28 - (streak - 0.5) * 0.06
    alb -= np.clip(tile_noise(7, base=8) - 0.62, 0, 1) * 0.35  # polvo de regolito
    alb += riv * 0.04
    alb3 = np.stack([alb, alb * 0.995, alb * 0.985], -1)
    save_png(os.path.join(OUT, "hull_alb.png"), alb3)
    height += (tile_noise(7, base=16) - 0.5) * 0.08
    save_png(os.path.join(OUT, "hull_nrm.png"), normal_from_height(blur(height, 1), 6.0))


def floor():
    ps = S // 2  # placas de 1 m
    d = np.minimum(np.minimum(xx % ps, ps - xx % ps), np.minimum(yy % ps, ps - yy % ps))
    seam = np.clip(1.0 - d / 3.0, 0, 1)
    # diamantes alternados (chapa antideslizante), 24 px
    p = 24.0
    u = (xx % p) / p - 0.5
    v = (yy % p) / p - 0.5
    cell = ((xx // p + yy // p) % 2).astype(bool)
    a = np.where(cell, (u + v), (u - v)) / 1.414
    b = np.where(cell, (u - v), (u + v)) / 1.414
    diamond = np.clip(1.0 - (np.abs(a) / 0.36 + np.abs(b) / 0.09), 0, 1) ** 0.5
    height = diamond * 0.8 - seam * 1.2
    # tornillos en las esquinas
    cx = np.minimum(xx % ps, ps - xx % ps)
    cy = np.minimum(yy % ps, ps - yy % ps)
    bolt = np.clip(1.0 - np.sqrt((cx - 22) ** 2 + (cy - 22) ** 2) / 6.0, 0, 1)
    height += bolt * 0.7
    wear = tile_noise(6, base=4)
    alb = 0.86 + diamond * 0.08 - seam * 0.3 - (wear - 0.5) * 0.14 - bolt * 0.1
    alb -= np.clip(tile_noise(7, base=8) - 0.6, 0, 1) * 0.3
    save_png(os.path.join(OUT, "floor_alb.png"), np.stack([alb, alb, alb * 1.01], -1))
    save_png(os.path.join(OUT, "floor_nrm.png"), normal_from_height(blur(height, 1), 5.0))


def slab():
    ps = S // 4  # losas de 1 m en una textura de 4 m
    d = np.minimum(np.minimum(xx % ps, ps - xx % ps), np.minimum(yy % ps, ps - yy % ps))
    seam = np.clip(1.0 - d / 2.5, 0, 1)
    grain = tile_noise(8, base=8, persistence=0.6)
    pits = np.clip(tile_noise(8, base=32) - 0.7, 0, 1) * 3.0
    height = (grain - 0.5) * 0.6 - seam - pits * 0.5
    alb = 0.9 + (grain - 0.5) * 0.22 - seam * 0.25 - pits * 0.2
    save_png(os.path.join(OUT, "slab_alb.png"), np.stack([alb, alb * 0.98, alb * 0.95], -1))
    save_png(os.path.join(OUT, "slab_nrm.png"), normal_from_height(blur(height, 1), 4.0))


os.makedirs(OUT, exist_ok=True)
hull()
floor()
slab()
