"""SPATIUM IV — Rocas y depósitos de recursos lunares.

Genera mallas por desplazamiento de ruido (formas de roca angulosas, típicas de
bloques de eyecta lunar: sin erosión por agua ni viento) y exporta un GLB por pieza.
Las rocas no llevan UV: en Godot usan un material triplanar con la textura de roca lunar.

Uso: blender -b --factory-startup --python tools/blender/build_rocks.py -- <raiz_repo> [--preview <dir>]
"""
import math
import os
import random
import sys

import bmesh
import bpy
from mathutils import Vector, noise

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else os.getcwd()
OUT = os.path.join(ROOT, "game", "assets", "models", "environment", "moon")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def material(name, hexcol, rough=0.85, metal=0.0, emission=None, strength=0.0, alpha=1.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emission:
        b.inputs["Emission Color"].default_value = (*srgb(emission), 1)
        b.inputs["Emission Strength"].default_value = strength
    if alpha < 1.0:
        b.inputs["Alpha"].default_value = alpha
        m.blend_method = "BLEND" if hasattr(m, "blend_method") else None
    return m


MAT = {
    "rock": material("MoonRock", "#8E8A84"),
    "basalt": material("IlmeniteBasalt", "#3E3E42", rough=0.7),
    "ilmenite": material("IlmeniteCrystal", "#6A707C", rough=0.3, metal=0.75),
    "ice": material("WaterIce", "#BFE6FF", rough=0.08, emission="#7FD3FF", strength=0.25, alpha=0.85),
    "regolith": material("RegolithFine", "#9C978F", rough=0.95),
    "breccia": material("BrecciaSample", "#A39A8E", rough=0.8),
    "anorthosite": material("Anorthosite", "#D9D5CC", rough=0.75),
}


def clear():
    for o in list(bpy.data.objects):
        bpy.data.objects.remove(o, do_unlink=True)


def rock_mesh(name, radius, seed, subdiv=3, squash=(1.0, 1.0, 0.7), rough=0.35, facets=0.6):
    """Roca angulosa: icosfera + ruido + aplanado de facetas (planos de fractura)."""
    rnd = random.Random(seed)
    bm = bmesh.new()
    bmesh.ops.create_icosphere(bm, subdivisions=subdiv, radius=radius)
    off = Vector((rnd.uniform(-50, 50), rnd.uniform(-50, 50), rnd.uniform(-50, 50)))
    planes = [Vector((rnd.uniform(-1, 1), rnd.uniform(-1, 1), rnd.uniform(-0.6, 1))).normalized() for _ in range(rnd.randint(4, 7))]
    for v in bm.verts:
        n = v.co.normalized()
        d = noise.fractal(v.co / radius * 1.3 + off, 0.55, 2.1, 4) * rough
        d += noise.noise(v.co / radius * 4.0 + off) * rough * 0.25
        p = n * radius * (1.0 + d)
        # Planos de fractura: recortan la forma y dejan caras planas
        for pl in planes:
            lim = radius * (0.72 + rnd.random() * 0.1)
            k = p.dot(pl)
            if k > lim:
                p -= pl * (k - lim) * facets
        v.co = Vector((p.x * squash[0], p.y * squash[1], p.z * squash[2]))
    # Apoyo plano: la base queda un poco enterrada
    min_z = min(v.co.z for v in bm.verts)
    for v in bm.verts:
        v.co.z -= min_z + radius * 0.18 * squash[2]
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    obj = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(obj)
    for p in me.polygons:
        p.use_smooth = True
    return obj


def add_mat(obj, mat):
    obj.data.materials.append(mat)


def crystals(prefix, base_obj, count, mat, seed, size=0.08, spread=0.5, height=0.3, tilt=0.6):
    """Cristales/vetas que asoman desde una roca (prismas hexagonales)."""
    rnd = random.Random(seed)
    objs = []
    for i in range(count):
        bpy.ops.mesh.primitive_cylinder_add(vertices=6, radius=size * rnd.uniform(0.6, 1.2), depth=size * rnd.uniform(2.5, 5.0))
        c = bpy.context.active_object
        c.name = f"{prefix}{i}"
        ang = rnd.uniform(0, math.tau)
        r = spread * math.sqrt(rnd.random())
        c.location = (math.cos(ang) * r, math.sin(ang) * r, height * rnd.uniform(0.4, 1.0))
        c.rotation_euler = (rnd.uniform(-tilt, tilt), rnd.uniform(-tilt, tilt), rnd.uniform(0, math.pi))
        # Punta del cristal
        bm = bmesh.new()
        bm.from_mesh(c.data)
        top = [v for v in bm.verts if v.co.z > 0]
        for v in top:
            v.co.x *= 0.45
            v.co.y *= 0.45
        bm.to_mesh(c.data)
        bm.free()
        c.data.materials.append(mat)
        objs.append(c)
    return objs


def join(objs, name):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    for o in objs:
        o.select_set(True)
    bpy.context.view_layer.objects.active = objs[0]
    bpy.ops.object.join()
    o = bpy.context.active_object
    o.name = name
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return o


def export(obj, filename):
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.context.view_layer.objects.active = obj
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False)
    tris = sum(len(p.vertices) - 2 for p in obj.data.polygons)
    print(f"[rocks] {filename}: {tris} tris")
    return path


exports = []

# --- Rocas grandes (bloques de eyecta) ----------------------------------------
for i, (r, sq, seed) in enumerate([(1.0, (1.2, 0.9, 0.75), 11), (1.0, (0.9, 1.0, 0.95), 23), (1.0, (1.4, 1.1, 0.55), 37)]):
    clear()
    o = rock_mesh(f"Boulder{i}", r, seed, subdiv=4, squash=sq, rough=0.42)
    add_mat(o, MAT["rock"])
    exports.append(export(o, f"boulder_{chr(97 + i)}.glb"))

# --- Piedras chicas (dispersión masiva, sin colisión) -------------------------
for i, seed in enumerate((5, 8, 13)):
    clear()
    o = rock_mesh(f"Pebble{i}", 1.0, seed, subdiv=2, squash=(1.0, 0.85, 0.6), rough=0.5)
    add_mat(o, MAT["rock"])
    exports.append(export(o, f"pebble_{chr(97 + i)}.glb"))

# --- Depósito de hierro: basalto rico en ilmenita (FeTiO3) ---------------------
clear()
base = rock_mesh("IronDeposit", 0.75, 101, subdiv=3, squash=(1.3, 1.1, 0.7), rough=0.38)
add_mat(base, MAT["basalt"])
cr = crystals("Ilm", base, 9, MAT["ilmenite"], 7, size=0.06, spread=0.55, height=0.42, tilt=0.7)
exports.append(export(join([base] + cr, "IronDeposit"), "deposit_iron.glb"))

# --- Hielo de agua: bloques cristalinos semienterrados en regolito -------------
clear()
mound = rock_mesh("IceBed", 0.9, 202, subdiv=3, squash=(1.4, 1.3, 0.28), rough=0.2)
add_mat(mound, MAT["regolith"])
ice = crystals("Ice", mound, 12, MAT["ice"], 9, size=0.09, spread=0.7, height=0.12, tilt=0.9)
exports.append(export(join([mound] + ice, "IceDeposit"), "deposit_ice.glb"))

# --- Montículo de regolito fino ------------------------------------------------
clear()
o = rock_mesh("RegolithMound", 0.8, 303, subdiv=3, squash=(1.5, 1.4, 0.32), rough=0.12, facets=0.0)
add_mat(o, MAT["regolith"])
exports.append(export(o, "deposit_regolith.glb"))

# --- Muestra geológica: brecha y anortosita ------------------------------------
clear()
o = rock_mesh("SampleBreccia", 0.28, 404, subdiv=3, squash=(1.2, 0.9, 0.8), rough=0.45)
add_mat(o, MAT["breccia"])
chips = crystals("Clast", o, 6, MAT["anorthosite"], 3, size=0.035, spread=0.18, height=0.12, tilt=1.2)
exports.append(export(join([o] + chips, "GeoSample"), "sample_breccia.glb"))

print(f"[rocks] {len(exports)} modelos exportados a {OUT}")
