"""Genera la Región Lunar 01 de SPATIUM IV (heightmap + puntos de interés).

Ejecutar con el Python de Blender (trae numpy):
  blender -b --factory-startup --python tools/generate_moon_region.py -- <raiz_del_repo>

Salidas:
  art_source/terrain/moon_region_01_height.exr   alturas en metros (float32, canal R)
  game/worlds/moon/data/moon_region_01_features.json   cráteres y zonas para el juego

Morfología (valores ADAPTADOS de la literatura sobre cráteres simples lunares):
  - profundidad ~ 0,2 × diámetro (cráteres frescos; los degradados, menos)
  - altura del borde ~ 0,036 × diámetro
  - eyecta que decae aprox. con (r/R)^-3 fuera del borde
  - frecuencia de tamaños según ley de potencias N(>D) ∝ D^-2
El relieve base usa síntesis espectral (ruido 1/f^β). Todo es determinista (semilla fija).
"""
import json
import math
import os
import sys

import numpy as np

SIZE = 2048            # vértices por lado (1 m de separación -> 2,048 km)
HALF = SIZE / 2.0
SEED = 4_2026
SPAWN = (0.0, 0.0)     # sitio de alunizaje (centro)
SPAWN_FLAT_R = 70.0

rng = np.random.default_rng(SEED)
ys, xs = np.mgrid[0:SIZE, 0:SIZE].astype(np.float32)
X = xs - HALF          # metros, +X = este
Z = ys - HALF          # metros, +Z = sur (convención Godot: -Z = norte)


def spectral_noise(beta: float, seed: int) -> np.ndarray:
    """Ruido fractal periódico 1/f^beta normalizado a [-1, 1]."""
    r = np.random.default_rng(seed)
    white = r.standard_normal((SIZE, SIZE)).astype(np.float32)
    f = np.fft.fft2(white)
    kx = np.fft.fftfreq(SIZE)[None, :]
    ky = np.fft.fftfreq(SIZE)[:, None]
    k = np.sqrt(kx * kx + ky * ky)
    k[0, 0] = 1.0
    f *= np.power(k, -beta / 2.0)  # espectro de potencia ∝ k^-beta
    f[0, 0] = 0.0
    n = np.real(np.fft.ifft2(f)).astype(np.float32)
    return n / np.max(np.abs(n))


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


# --- 1. Relieve base: planicie ondulada de tierras altas -------------------
height = spectral_noise(3.6, SEED + 1) * 22.0
height += spectral_noise(2.6, SEED + 2) * 1.2           # rugosidad media

# --- 2. Macizo montañoso al norte y lomas en los bordes ---------------------
macro = spectral_noise(4.2, SEED + 3)                     # forma general (muy baja frecuencia)
ridged = (1.0 - np.abs(spectral_noise(3.8, SEED + 4))) ** 2.0
ridged_fine = (1.0 - np.abs(spectral_noise(3.0, SEED + 6))) ** 2.0
# Frente montañoso del norte con traza irregular
z_front = -430.0 + spectral_noise(4.0, SEED + 7) * 150.0
north = smoothstep(z_front, z_front - 480.0, Z)            # crece hacia -Z (norte)
height += north * (70.0 + ridged * 360.0 + macro * 60.0 + ridged_fine * 25.0)
# Cierre natural del mapa: lomas con contorno orgánico (no una caja)
edge = (np.abs(X) ** 4 + np.abs(Z) ** 4) ** 0.25 + spectral_noise(3.8, SEED + 8) * 110.0
rim_wall = smoothstep(760.0, 1000.0, edge)
height += rim_wall * (80.0 + ridged * 240.0 + ridged_fine * 20.0)
# Macizo aislado al oeste (punto de referencia visual)
d_w = np.sqrt((X + 620.0) ** 2 + (Z - 150.0) ** 2) * (1.0 + 0.25 * spectral_noise(3.6, SEED + 9))
height += np.exp(-(d_w / 170.0) ** 2) * (110.0 + ridged * 90.0 + ridged_fine * 12.0)

# --- 3. Cráteres -------------------------------------------------------------
craters = []


def add_crater(cx: float, cz: float, diameter: float, freshness: float, name: str = "") -> None:
    R = diameter / 2.0
    depth = 0.2 * diameter * (0.45 + 0.55 * freshness)
    rim = 0.036 * diameter * (0.5 + 0.5 * freshness)
    ext = 3.0 * R
    x0, x1 = int(max(0, cx + HALF - ext)), int(min(SIZE, cx + HALF + ext + 1))
    z0, z1 = int(max(0, cz + HALF - ext)), int(min(SIZE, cz + HALF + ext + 1))
    if x0 >= x1 or z0 >= z1:
        return
    dx = X[z0:z1, x0:x1] - cx
    dz = Z[z0:z1, x0:x1] - cz
    r = np.sqrt(dx * dx + dz * dz) / R
    # Borde levemente irregular
    ang = np.arctan2(dz, dx)
    wobble = 1.0
    for k, amp in ((2, 0.025), (3, 0.018), (5, 0.010), (9, 0.006)):
        wobble = wobble + amp * np.sin(ang * k + rng.uniform(0.0, 6.283))
    r = r * wobble
    inside = r < 1.0
    floor_r = 0.35 if diameter > 250 else 0.0               # cráteres grandes: fondo plano
    rr = np.maximum(r, floor_r)
    bowl = rim - depth * (1.0 - ((rr - floor_r) / (1.0 - floor_r)) ** 2) if floor_r > 0 else rim - depth * (1.0 - r * r)
    ejecta = rim * np.power(np.maximum(r, 1.0), -3.0) * (1.0 - smoothstep(2.2, 3.0, r))
    delta = np.where(inside, bowl, ejecta)
    # Atenuar la forma del terreno anterior dentro del cráter (el impacto la borra)
    region = height[z0:z1, x0:x1]
    local = float(np.mean(region[inside])) if np.any(inside) else 0.0
    erase = np.where(inside, 1.0 - smoothstep(0.6, 1.0, r), 0.0) * freshness * 0.7
    height[z0:z1, x0:x1] = region * (1.0 - erase) + local * erase + delta
    if diameter >= 40.0:
        craters.append({"id": name or f"crater_{len(craters):03d}", "x": round(cx, 1), "z": round(cz, 1),
                        "diameter_m": round(diameter, 1), "depth_m": round(depth, 1),
                        "rim_height_m": round(rim, 1), "freshness": round(freshness, 2)})


def far_from_spawn(cx, cz, margin):
    return math.hypot(cx - SPAWN[0], cz - SPAWN[1]) > margin


# Cráter principal (punto de interés: posible hielo en sombra permanente)
add_crater(430.0, 330.0, 540.0, 0.95, "crater_albor")
# Cráteres medianos
placed = 0
while placed < 9:
    cx, cz = rng.uniform(-850, 850, 2)
    d = float(rng.uniform(70, 230))
    if far_from_spawn(cx, cz, 160 + d) and math.hypot(cx - 430, cz - 330) > 270 + d / 2:
        add_crater(cx, cz, d, float(rng.uniform(0.35, 1.0)))
        placed += 1
# Cráteres chicos: ley de potencias N(>D) ∝ D^-2  ->  D = Dmin * u^(-1/2)
for _ in range(900):
    d = min(6.0 * rng.random() ** -0.5, 60.0)
    cx, cz = rng.uniform(-980, 980, 2)
    if not far_from_spawn(cx, cz, 25 + d):
        d *= 0.4                                       # cerca del sitio de alunizaje, solo marcas leves
    add_crater(cx, cz, d, float(rng.uniform(0.2, 1.0)))
# Micro-cráteres
for _ in range(2500):
    d = min(1.5 * rng.random() ** -0.5, 5.0)
    cx, cz = rng.uniform(-1000, 1000, 2)
    add_crater(cx, cz, d, float(rng.uniform(0.3, 1.0)))

# --- 3b. Talud de acceso al cráter Albor --------------------------------------
# Las paredes de un cráter fresco superan los 45°: sin un acceso, quien baja no
# puede salir. Muchos cráteres reales tienen taludes de derrumbe (paredes
# colapsadas); acá uno mira hacia el sitio de alunizaje, con ~20° de pendiente.
def carve_ramp(cx, cz, R, toward, r0, r1, half_w, falloff):
    d = np.array(toward, dtype=np.float32) - np.array([cx, cz], dtype=np.float32)
    d /= np.linalg.norm(d)
    ax, az = cx + d[0] * r0, cz + d[1] * r0
    bx, bz = cx + d[0] * r1, cz + d[1] * r1
    ha = float(height[int(az + HALF), int(ax + HALF)])
    hb = float(height[int(bz + HALF), int(bx + HALF)])
    vx, vz = bx - ax, bz - az
    L2 = vx * vx + vz * vz
    t = np.clip(((X - ax) * vx + (Z - az) * vz) / L2, 0.0, 1.0)
    px, pz = ax + t * vx, az + t * vz
    dist = np.sqrt((X - px) ** 2 + (Z - pz) ** 2)
    w = 1.0 - smoothstep(half_w, half_w + falloff, dist)
    # solo a lo largo del tramo (no más allá de los extremos)
    raw_t = ((X - ax) * vx + (Z - az) * vz) / L2
    w *= smoothstep(-0.05, 0.02, raw_t) * (1.0 - smoothstep(0.98, 1.05, raw_t))
    target = ha + (hb - ha) * (t * t * (3.0 - 2.0 * t) * 0.35 + t * 0.65)
    np.copyto(height, (height * (1.0 - w) + target * w).astype(np.float32))


carve_ramp(430.0, 330.0, 270.0, (0.0, 0.0), 0.22 * 270.0, 1.55 * 270.0, 9.0, 22.0)

# --- 4. Sitio de alunizaje: planicie suave ----------------------------------
d_s = np.sqrt((X - SPAWN[0]) ** 2 + (Z - SPAWN[1]) ** 2)
w = 1.0 - smoothstep(SPAWN_FLAT_R * 0.6, SPAWN_FLAT_R * 1.6, d_s)
spawn_h = float(np.mean(height[(d_s < SPAWN_FLAT_R)]))
height = height * (1.0 - w * 0.85) + spawn_h * w * 0.85

# --- 5. Detalle fino --------------------------------------------------------
height += spectral_noise(2.0, SEED + 5) * 0.35
height -= spawn_h                                       # el sitio de alunizaje queda a ~0 m

# --- Salida ------------------------------------------------------------------
root = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.getcwd()
out_exr = os.path.join(root, "art_source", "terrain", "moon_region_01_height.exr")
out_json = os.path.join(root, "game", "worlds", "moon", "data", "moon_region_01_features.json")
os.makedirs(os.path.dirname(out_exr), exist_ok=True)
os.makedirs(os.path.dirname(out_json), exist_ok=True)

import bpy  # noqa: E402  (solo disponible dentro de Blender)

img = bpy.data.images.new("moon_height", SIZE, SIZE, alpha=False, float_buffer=True)
img.colorspace_settings.name = "Non-Color"
px = np.zeros((SIZE, SIZE, 4), dtype=np.float32)
# Blender guarda las filas de abajo hacia arriba: invertir para que fila 0 = -Z (norte)
flipped = height[::-1, :]
px[..., 0] = flipped
px[..., 1] = flipped
px[..., 2] = flipped
px[..., 3] = 1.0
img.pixels.foreach_set(px.ravel())
img.filepath_raw = out_exr
img.file_format = "OPEN_EXR"
img.save()

features = {
    "region": "moon_region_01",
    "size_m": SIZE,
    "vertex_spacing_m": 1.0,
    "origin": "centro del mapa; +X este, -Z norte",
    "spawn": {"x": SPAWN[0], "z": SPAWN[1], "flat_radius_m": SPAWN_FLAT_R},
    "height_range_m": [round(float(height.min()), 1), round(float(height.max()), 1)],
    "craters": sorted(craters, key=lambda c: -c["diameter_m"]),
    "zones": {
        "north_massif": {"z_max": -380.0, "description_key": "ZONE_NORTH_MASSIF"},
        "west_massif": {"x": -620.0, "z": 150.0, "radius_m": 150.0, "description_key": "ZONE_WEST_MASSIF"},
    },
    "science": {
        "kind": "ADAPTED",
        "notes": "Proporciones de cráteres simples lunares (profundidad/diámetro ~0,2; borde ~0,036 D) y ley de potencias de tamaños; terreno procedimental, no es un lugar real.",
    },
}
with open(out_json, "w", encoding="utf-8") as f:
    json.dump(features, f, ensure_ascii=False, indent=1)
print(f"[moon] alturas {height.min():.1f} .. {height.max():.1f} m; cráteres registrados: {len(craters)}")
print(f"[moon] {out_exr}")
