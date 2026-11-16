"""Empaqueta texturas PBR al formato de Terrain3D.

Terrain3D espera por material:
  *_alb_h.png  -> RGB = albedo, A = altura (displacement)
  *_nrm_r.png  -> RGB = normal OpenGL, A = rugosidad

Uso (con el Python de Blender, que trae numpy):
  blender -b --python tools/pack_terrain_textures.py -- <dir_origen> <dir_destino> <nombre_origen>:<nombre_destino> ...

Ejemplo:
  blender -b --python tools/pack_terrain_textures.py -- dl_tex game/assets/textures/terrain \
      moon_dusted_02:moon_regolith moon_03:moon_rocky
Archivos de origen esperados: <nombre>_diff.png, _disp.png, _nor_gl.png, _rough.png
"""
import sys
import os

import bpy
import numpy as np


def load_rgba(path: str) -> np.ndarray:
    img = bpy.data.images.load(path, check_existing=False)
    img.colorspace_settings.name = "Non-Color"  # leer valores crudos, sin conversión
    w, h = img.size
    px = np.empty(w * h * 4, dtype=np.float32)
    img.pixels.foreach_get(px)
    bpy.data.images.remove(img)
    return px.reshape(h, w, 4)


def save_rgba(arr: np.ndarray, path: str) -> None:
    h, w, _ = arr.shape
    img = bpy.data.images.new(os.path.basename(path), w, h, alpha=True, float_buffer=False)
    img.colorspace_settings.name = "Non-Color"
    img.alpha_mode = "STRAIGHT"
    img.pixels.foreach_set(np.clip(arr, 0.0, 1.0).astype(np.float32).ravel())
    img.filepath_raw = path
    img.file_format = "PNG"
    img.save()
    bpy.data.images.remove(img)


def pack(src_dir: str, dst_dir: str, src: str, dst: str) -> None:
    diff = load_rgba(os.path.join(src_dir, f"{src}_diff.png"))
    disp = load_rgba(os.path.join(src_dir, f"{src}_disp.png"))
    nrm = load_rgba(os.path.join(src_dir, f"{src}_nor_gl.png"))
    rough = load_rgba(os.path.join(src_dir, f"{src}_rough.png"))

    alb_h = diff.copy()
    d = disp[..., 0]
    alb_h[..., 3] = (d - d.min()) / max(d.max() - d.min(), 1e-6)  # altura normalizada 0..1
    nrm_r = nrm.copy()
    nrm_r[..., 3] = rough[..., 0]

    os.makedirs(dst_dir, exist_ok=True)
    save_rgba(alb_h, os.path.join(dst_dir, f"{dst}_alb_h.png"))
    save_rgba(nrm_r, os.path.join(dst_dir, f"{dst}_nrm_r.png"))
    print(f"[pack] {src} -> {dst} ({alb_h.shape[1]}x{alb_h.shape[0]})")


if __name__ == "__main__":
    args = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
    if len(args) < 3:
        raise SystemExit(__doc__)
    src_dir, dst_dir = args[0], args[1]
    for pair in args[2:]:
        s, t = pair.split(":")
        pack(src_dir, dst_dir, s, t)
