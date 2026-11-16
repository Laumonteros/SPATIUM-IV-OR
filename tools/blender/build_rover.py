"""SPATIUM IV — Rover presurizado "Selene" (exploración de larga distancia).

Cabina presurizada (el astronauta viaja adentro sin consumir el traje), 4 ruedas
de malla metálica independientes (nodos "Wheel_FL/FR/RL/RR"), panel solar en el
techo, faros y acentos naranjas. Escala real ~4,2 m de largo. Frente = -Y (Blender).

Uso: blender -b --factory-startup --python tools/blender/build_rover.py -- <raiz_repo> [--preview <dir>]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else os.getcwd()
PREVIEW = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else None
OUT = os.path.join(ROOT, "game", "assets", "models", "vehicles")
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)


def srgb(h):
    h = h.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


def mat(name, hexcol, rough=0.5, metal=0.0, emit=None, strength=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (*srgb(hexcol), 1)
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit:
        b.inputs["Emission Color"].default_value = (*srgb(emit), 1)
        b.inputs["Emission Strength"].default_value = strength
    return m


M = {
    "hull": mat("HullWhite", "#E9E7E2", 0.4), "hull2": mat("HullGrey", "#BFC3C8", 0.5),
    "metal": mat("Metal", "#B4BAC2", 0.38, 0.45), "dark": mat("DarkPanel", "#2A2E35", 0.6, 0.2),
    "accent": mat("Accent", "#FF8A3D", 0.45), "glass": mat("Window", "#2E4A63", 0.05, 0.3),
    "solar": mat("SolarCell", "#22355C", 0.2, 0.3), "tire": mat("WheelMesh", "#8C9097", 0.55, 0.6),
    "light": mat("LightWarm", "#FFE2B8", 0.2, 0.0, "#FFD39A", 8.0), "cyan": mat("LightCyan", "#4FD1E8", 0.2, 0.0, "#4FD1E8", 5.0),
    "foil": mat("GoldFoil", "#D9A845", 0.3, 0.55),
}
body_parts = []


def finish(o, m, bevel=0.0, subdiv=0, collect=True):
    o.data.materials.append(m)
    if bevel:
        md = o.modifiers.new("b", "BEVEL")
        md.width = bevel
        md.segments = 2
        md.limit_method = "ANGLE"
    if subdiv:
        md = o.modifiers.new("s", "SUBSURF")
        md.levels = subdiv
    bpy.context.view_layer.objects.active = o
    for x in bpy.context.selected_objects:
        x.select_set(False)
    o.select_set(True)
    bpy.ops.object.convert(target="MESH")
    bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    if collect:
        body_parts.append(o)
    return o


def box(loc, size, m, bevel=0.03, rot=(0, 0, 0), subdiv=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, m, bevel, subdiv)


def cyl(loc, r, depth, m, axis=(0, 0, 1), verts=24, bevel=0.01, collect=True):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth)
    o = bpy.context.active_object
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.location = loc
    return finish(o, m, bevel, collect=collect)


def strut(a, b, r, m):
    a, b = Vector(a), Vector(b)
    return cyl((a + b) / 2, r, (b - a).length, m, axis=b - a, verts=10, bevel=0.0)


# --- Chasis y cabina ---------------------------------------------------------
box((0, 0.2, 0.75), (2.0, 3.6, 0.35), M["hull2"], bevel=0.06)                       # plataforma
box((0, -0.35, 1.35), (1.85, 2.3, 1.0), M["hull"], bevel=0.25, subdiv=1)            # cabina presurizada
box((0, -1.42, 1.45), (1.55, 0.25, 0.55), M["glass"], bevel=0.1, rot=(math.radians(-25), 0, 0))  # parabrisas
for x in (-0.94, 0.94):
    box((x, -0.6, 1.45), (0.05, 1.0, 0.38), M["glass"], bevel=0.05)               # ventanas laterales
box((0, 1.25, 1.25), (1.6, 0.9, 0.75), M["hull2"], bevel=0.06)                      # módulo trasero (esclusa)
box((0, 1.71, 1.25), (0.8, 0.04, 0.6), M["dark"], bevel=0.02)                       # escotilla trasera
box((0, 1.74, 1.62), (0.35, 0.03, 0.05), M["cyan"], bevel=0.0)
box((0, -0.35, 1.9), (1.7, 2.0, 0.05), M["solar"], bevel=0.01)                      # panel solar en el techo
box((0, -0.35, 1.87), (1.75, 2.05, 0.03), M["metal"], bevel=0.0)
for y in (-1.0, 0.3):
    box((0, y, 0.98), (2.06, 0.08, 0.06), M["accent"], bevel=0.0)                  # franjas naranjas
box((0, 0.2, 0.55), (1.6, 2.8, 0.12), M["foil"], bevel=0.02)                        # aislamiento bajo el chasis
# Faros y barra de luces
for x in (-0.6, 0.6):
    box((x, -1.62, 1.0), (0.32, 0.08, 0.14), M["light"], bevel=0.02)
box((0, -0.9, 1.97), (1.2, 0.12, 0.06), M["light"], bevel=0.01)
# Antena y cámara de navegación
strut((0.6, 0.9, 1.6), (0.6, 0.9, 2.6), 0.02, M["metal"])
cyl((0.6, 0.9, 2.62), 0.18, 0.05, M["hull"], verts=20)
box((-0.55, -1.25, 2.0), (0.2, 0.2, 0.16), M["dark"], bevel=0.02)
# Defensas de las ruedas
for x in (-1.0, 1.0):
    for y in (-1.15, 1.35):
        box((x * 1.06, y, 1.0), (0.42, 1.05, 0.08), M["hull2"], bevel=0.03)
        strut((x * 0.85, y, 0.8), (x * 1.08, y, 0.45), 0.04, M["metal"])             # suspensión

for x in bpy.context.selected_objects:
    x.select_set(False)
for o in body_parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = body_parts[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = "Body"

# --- Ruedas de malla (nodos propios para que Godot las haga girar) -------------
WHEELS = {"Wheel_FL": (-1.12, -1.15), "Wheel_FR": (1.12, -1.15), "Wheel_RL": (-1.12, 1.35), "Wheel_RR": (1.12, 1.35)}
for name, (x, y) in WHEELS.items():
    parts = []
    parts.append(cyl((0, 0, 0), 0.48, 0.32, M["tire"], axis=(1, 0, 0), verts=28, bevel=0.03, collect=False))
    parts.append(cyl((0, 0, 0), 0.2, 0.36, M["dark"], axis=(1, 0, 0), verts=16, collect=False))
    for k in range(10):                                                               # tacos (chevrones)
        a = k * math.tau / 10
        bpy.ops.mesh.primitive_cube_add(size=1, location=(0, math.cos(a) * 0.49, math.sin(a) * 0.49), rotation=(a, 0, 0))
        g = bpy.context.active_object
        g.scale = (0.3, 0.05, 0.04)
        bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
        parts.append(finish(g, M["metal"], collect=False))
    for x2 in bpy.context.selected_objects:
        x2.select_set(False)
    for o in parts:
        o.select_set(True)
    bpy.context.view_layer.objects.active = parts[0]
    bpy.ops.object.join()
    w = bpy.context.active_object
    w.name = name
    w.location = (x, y, 0.48)

bpy.ops.object.select_all(action="SELECT")
path = os.path.join(OUT, "rover.glb")
bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True, export_yup=True, export_animations=False)
tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
print(f"[rover] {path}: {tris} tris")

if PREVIEW:
    scene = bpy.context.scene
    cam = bpy.data.objects.new("Cam", bpy.data.cameras.new("Cam"))
    scene.collection.objects.link(cam)
    sun = bpy.data.objects.new("Sun", bpy.data.lights.new("Sun", "SUN"))
    sun.data.energy = 4
    sun.rotation_euler = (math.radians(55), 0, math.radians(40))
    scene.collection.objects.link(sun)
    wd = bpy.data.worlds.new("W")
    wd.use_nodes = True
    wd.node_tree.nodes["Background"].inputs[0].default_value = (0.04, 0.045, 0.06, 1)
    scene.world = wd
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 700
    cam.location = (5.5, -6.0, 3.6)
    cam.rotation_euler = (Vector((0, 0, 1.0)) - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = os.path.join(PREVIEW, "rover.png")
    bpy.ops.render.render(write_still=True)
