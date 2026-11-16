"""Genera la textura del mapa (relieve sombreado + tinte por altura) de la Región Lunar 01.
Uso: blender -b --factory-startup --python tools/generate_map_texture.py -- <raiz_repo>
Orientación: arriba = norte (-Z), izquierda = oeste (-X); cubre 2048 x 2048 m."""
import os, sys
import bpy
import numpy as np
ROOT = sys.argv[sys.argv.index("--") + 1]
src = os.path.join(ROOT, "art_source", "terrain", "moon_region_01_height.exr")
out = os.path.join(ROOT, "game", "assets", "textures", "ui", "moon_region_01_map.png")
os.makedirs(os.path.dirname(out), exist_ok=True)
img = bpy.data.images.load(src)
w, h = img.size
px = np.empty(w * h * 4, np.float32)
img.pixels.foreach_get(px)
H = px.reshape(h, w, 4)[..., 0][::2, ::2]          # 1024 x 1024, filas de abajo hacia arriba (como Blender)
gy, gx = np.gradient(H, 2.0)
az, alt = np.radians(315), np.radians(35)
slope = np.arctan(np.hypot(gx, gy))
aspect = np.arctan2(-gx, gy)
shade = np.clip(np.sin(alt) * np.cos(slope) + np.cos(alt) * np.sin(slope) * np.cos(az - aspect), 0, 1)
hn = np.clip((H - (-100.0)) / 500.0, 0, 1)
base = np.stack([0.30 + 0.25 * hn, 0.31 + 0.24 * hn, 0.34 + 0.22 * hn], -1)
rgb = base * (0.35 + 0.85 * shade[..., None])
rgb = np.clip(rgb, 0, 1) ** (1 / 1.6)
o = np.ones((rgb.shape[0], rgb.shape[1], 4), np.float32)
o[..., :3] = rgb
im = bpy.data.images.new("map", o.shape[1], o.shape[0])
im.pixels.foreach_set(o.ravel())
im.filepath_raw = out
im.file_format = "PNG"
im.save()
print("[map]", out)
