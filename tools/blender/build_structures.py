"""SPATIUM IV — Estructuras de la base lunar (módulo de alunizaje + instalaciones).

Estilo de la biblia de arte: hardware creíble (inspirado en hábitats y módulos reales),
casco blanco, acento naranja SPATIUM, lámina térmica dorada, metal y luces cian.
Cada modelo se exporta como GLB. Nodos con nombre especial (los usa Godot):
  - "Anim_*"  piezas que se animan por código (panel que sigue al sol, ventilador, etc.)
  - "Light_*" posiciones de luces

Uso: blender -b --factory-startup --python tools/blender/build_structures.py -- <raiz_repo> [--preview <dir>]
"""
import math
import os
import sys

import bpy
from mathutils import Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else os.getcwd()
PREVIEW = ARGS[ARGS.index("--preview") + 1] if "--preview" in ARGS else None
OUT = os.path.join(ROOT, "game", "assets", "models", "structures")
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
    m.diffuse_color = (*srgb(hexcol), 1)
    return m


M = {
    "hull": mat("HullWhite", "#E9E7E2", 0.4),
    "hull2": mat("HullGrey", "#BFC3C8", 0.5),
    "metal": mat("Metal", "#B4BAC2", 0.38, 0.45),
    "dark": mat("DarkPanel", "#2A2E35", 0.6, 0.2),
    "accent": mat("Accent", "#FF8A3D", 0.45),
    "foil": mat("GoldFoil", "#D9A845", 0.3, 0.55),
    "solar": mat("SolarCell", "#22355C", 0.2, 0.3),
    "glass": mat("Window", "#9FD8F0", 0.05, 0.0, "#BDEBFF", 1.5),
    "cyan": mat("LightCyan", "#4FD1E8", 0.2, 0.0, "#4FD1E8", 5.0),
    "warm": mat("LightWarm", "#FFE2B8", 0.2, 0.0, "#FFD39A", 6.0),
    "orange_light": mat("LightOrange", "#FF8A3D", 0.2, 0.0, "#FF8A3D", 5.0),
    "regolith": mat("RegolithBag", "#A49D92", 0.95),
    "ice": mat("IceTank", "#BFE6FF", 0.1, 0.0, "#7FD3FF", 0.6),
}

parts = []


def finish(o, m, bevel=0.0, subdiv=0, smooth=True, name=None):
    if name:
        o.name = name
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
    if smooth:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(35))
    parts.append(o)
    return o


def box(loc, size, m, bevel=0.02, rot=(0, 0, 0), name=None, subdiv=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, m, bevel, subdiv, name=name)


def cyl(loc, r, depth, m, axis=(0, 0, 1), verts=32, bevel=0.01, name=None, r2=None):
    if r2 is None:
        bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=depth)
    else:
        bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r, radius2=r2, depth=depth)
    o = bpy.context.active_object
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.location = loc
    return finish(o, m, bevel, name=name)


def strut(a, b, r, m, name=None):
    a, b = Vector(a), Vector(b)
    return cyl((a + b) / 2, r, (b - a).length, m, axis=b - a, verts=10, bevel=0.0, name=name)


def sphere(loc, r, m, scale=(1, 1, 1), name=None, seg=32):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=r, location=loc)
    o = bpy.context.active_object
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return finish(o, m, name=name)


def torus(loc, R, r, m, axis=(0, 0, 1), name=None):
    bpy.ops.mesh.primitive_torus_add(major_segments=40, minor_segments=10, major_radius=R, minor_radius=r)
    o = bpy.context.active_object
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.location = loc
    return finish(o, m, name=name)


def empty(name, loc):
    e = bpy.data.objects.new(name, None)
    e.location = loc
    bpy.context.scene.collection.objects.link(e)
    return e


def export(filename, keep_separate=()):
    """Une todo salvo las piezas animables (que quedan como nodos propios) y exporta."""
    static = [p for p in parts if not any(p.name.startswith(k) for k in keep_separate)]
    for x in bpy.context.selected_objects:
        x.select_set(False)
    if static:
        for p in static:
            p.select_set(True)
        bpy.context.view_layer.objects.active = static[0]
        bpy.ops.object.join()
        bpy.context.active_object.name = "Body"
    for o in bpy.context.scene.objects:
        o.select_set(True)
    path = os.path.join(OUT, filename)
    bpy.ops.export_scene.gltf(filepath=path, export_format="GLB", use_selection=True, export_apply=True,
                              export_yup=True, export_animations=False, export_extras=True)
    tris = sum(sum(len(p.vertices) - 2 for p in o.data.polygons) for o in bpy.context.scene.objects if o.type == "MESH")
    print(f"[structures] {filename}: {tris} tris")
    if PREVIEW:
        render_preview(filename.replace(".glb", ".png"))


def render_preview(name):
    scene = bpy.context.scene
    cam = bpy.data.objects.get("PrevCam")
    if cam is None:
        cam = bpy.data.objects.new("PrevCam", bpy.data.cameras.new("PrevCam"))
        scene.collection.objects.link(cam)
        sun = bpy.data.objects.new("PrevSun", bpy.data.lights.new("PrevSun", "SUN"))
        sun.data.energy = 4
        sun.rotation_euler = (math.radians(55), 0, math.radians(40))
        scene.collection.objects.link(sun)
        w = bpy.data.worlds.new("W")
        w.use_nodes = True
        w.node_tree.nodes["Background"].inputs[0].default_value = (0.04, 0.045, 0.06, 1)
        scene.world = w
        scene.render.engine = "BLENDER_EEVEE"
        scene.render.resolution_x = scene.render.resolution_y = 700
    meshes = [o for o in scene.objects if o.type == "MESH"]
    pts = [o.matrix_world @ Vector(c) for o in meshes for c in o.bound_box]
    mn = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    mx = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    c = (mn + mx) / 2
    size = (mx - mn).length
    cam.location = c + Vector((1.0, -1.3, 0.75)).normalized() * size * 1.35
    cam.rotation_euler = (c - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.camera = cam
    scene.render.filepath = os.path.join(PREVIEW, name)
    bpy.ops.render.render(write_still=True)


def reset():
    global parts
    for o in list(bpy.data.objects):
        if o.name.startswith("Prev"):
            continue
        bpy.data.objects.remove(o, do_unlink=True)
    parts = []


# =============================================================================
# Módulo de alunizaje "Ariel" (refugio inicial)
# =============================================================================
reset()
# Etapa de descenso: octógono con lámina térmica dorada
cyl((0, 0, 1.25), 1.9, 1.1, M["foil"], verts=8, bevel=0.03)
cyl((0, 0, 1.83), 1.95, 0.08, M["metal"], verts=8)
for i in range(4):
    a = math.radians(45 + 90 * i)
    d = Vector((math.cos(a), math.sin(a), 0))
    top = d * 1.7 + Vector((0, 0, 1.4))
    foot = d * 3.1 + Vector((0, 0, 0.15))
    strut(top, foot, 0.07, M["metal"])
    strut(d * 1.6 + Vector((0, 0, 0.8)), foot + Vector((0, 0, 0.1)), 0.04, M["metal"])
    cyl(foot + Vector((0, 0, -0.05)), 0.38, 0.12, M["hull2"], verts=24, r2=0.3)
# Escalera hacia la escotilla (frente: -Y)
for k in range(6):
    box((0, -2.15, 0.35 + k * 0.28), (0.6, 0.05, 0.04), M["metal"], bevel=0.0)
strut((-0.3, -2.1, 0.15), (-0.3, -1.95, 1.9), 0.03, M["metal"])
strut((0.3, -2.1, 0.15), (0.3, -1.95, 1.9), 0.03, M["metal"])
# Etapa de ascenso / cabina presurizada
cyl((0, 0.1, 2.75), 1.45, 1.7, M["hull"], verts=40, bevel=0.06)
sphere((0, 0.1, 3.6), 1.45, M["hull"], scale=(1, 1, 0.55))
box((0, -1.32, 2.55), (0.9, 0.3, 1.2), M["hull2"], bevel=0.06)
box((0, -1.48, 2.55), (0.62, 0.04, 0.95), M["dark"], bevel=0.02)                 # escotilla
box((0, -1.51, 2.55), (0.12, 0.03, 0.08), M["orange_light"], bevel=0.0)
for x in (-0.7, 0.7):
    box((x, -1.28, 3.25), (0.42, 0.06, 0.3), M["glass"], bevel=0.02, rot=(0.3, 0, 0))  # ventanas
torus((0, 0.1, 1.95), 1.45, 0.06, M["accent"])
torus((0, 0.1, 3.55), 1.38, 0.04, M["accent"])
# Antena de alta ganancia y propulsores
strut((0.9, 0.9, 3.9), (1.2, 1.2, 4.6), 0.03, M["metal"])
sphere((1.25, 1.25, 4.72), 0.35, M["hull"], scale=(1, 1, 0.35))
for i in range(4):
    a = math.radians(90 * i)
    box((math.cos(a) * 1.55, 0.1 + math.sin(a) * 1.55, 2.9), (0.22, 0.22, 0.3), M["dark"], bevel=0.03)
empty("Light_Hatch", (0, -1.7, 3.3))
empty("Light_Flood", (0, 0, 4.4))
export("lander.glb")

# =============================================================================
# Hábitat (módulo presurizado con esclusa)
# =============================================================================
reset()
cyl((0, 0, 1.6), 2.4, 2.6, M["hull"], verts=36, bevel=0.08)                       # cuerpo
sphere((0, 0, 2.9), 2.4, M["hull"], scale=(1, 1, 0.42))                          # techo
for i in range(12):
    a = math.radians(30 * i)
    box((math.cos(a) * 2.38, math.sin(a) * 2.38, 1.6), (0.08, 0.08, 2.5), M["hull2"], bevel=0.01, rot=(0, 0, a))
torus((0, 0, 0.4), 2.42, 0.08, M["metal"])
torus((0, 0, 2.85), 2.36, 0.06, M["accent"])
# Base y escudo de regolito (sacos) para radiación
for i in range(20):
    a = math.radians(18 * i)
    box((math.cos(a) * 2.75, math.sin(a) * 2.75, 0.22), (0.7, 0.45, 0.4), M["regolith"], bevel=0.12, rot=(0, 0, a))
# Esclusa al frente
cyl((0, -2.8, 1.25), 0.95, 1.6, M["hull2"], axis=(0, 1, 0), verts=32, bevel=0.04)
box((0, -3.62, 1.2), (1.0, 0.06, 1.6), M["dark"], bevel=0.03)
box((0, -3.67, 2.15), (0.5, 0.04, 0.08), M["cyan"], bevel=0.0)
# Ventanas con luz cálida interior
for a in (40, 140, 220, 320):
    r = math.radians(a)
    box((math.cos(r) * 2.42, math.sin(r) * 2.42, 2.0), (0.12, 0.7, 0.45), M["glass"], bevel=0.04, rot=(0, 0, r))
# Equipos en el techo: radiadores y antena
for s in (-1, 1):
    box((s * 1.0, 0.8, 3.95), (0.9, 0.05, 0.6), M["hull2"], bevel=0.01)
cyl((0, 0, 4.0), 0.25, 0.3, M["metal"], verts=20)
strut((0, 0, 4.1), (0, 0, 5.0), 0.02, M["metal"])
sphere((0, 0, 5.05), 0.07, M["orange_light"], seg=12)
empty("Light_Door", (0, -3.9, 2.4))
export("habitat.glb")

# =============================================================================
# Panel solar con seguidor de un eje (Anim_Panel gira sobre el eje X).
# Dos caballetes en los extremos (4 patas) sostienen el eje por fuera del panel:
# al inclinarse, el panel nunca toca patas, eje ni suelo (inclinación máx. ±60°).
# =============================================================================
reset()
PIV = 2.2
for sx in (-1, 1):
    x = sx * 2.38
    for sy in (-1, 1):
        box((x, sy * 0.95, 0.06), (0.4, 0.4, 0.12), M["hull2"], bevel=0.02)   # zapata
        strut((x, sy * 0.95, 0.1), (x, 0.0, PIV - 0.08), 0.06, M["metal"])  # pata
    strut((x, -0.52, 1.0), (x, 0.52, 1.0), 0.035, M["metal"])                # travesaño
    cyl((x, 0, PIV), 0.13, 0.22, M["dark"], axis=(1, 0, 0), verts=16)          # cojinete
# largueros de base entre caballetes
for sy in (-1, 1):
    strut((-2.38, sy * 0.95, 0.12), (2.38, sy * 0.95, 0.12), 0.04, M["metal"])
# caja del inversor con franja de acento
box((2.38, 0.0, 0.55), (0.18, 0.42, 0.5), M["dark"], bevel=0.02)
box((2.48, 0.0, 0.7), (0.02, 0.3, 0.05), M["accent"], bevel=0.0)
bpy.ops.object.empty_add(location=(0, 0, PIV))
pivot = bpy.context.active_object
pivot.name = "Anim_Panel"
panel_parts = []
panel_parts.append(cyl((0, 0, PIV), 0.07, 4.6, M["metal"], axis=(1, 0, 0), verts=12))   # eje de torsión
panel_parts.append(box((0, 0, PIV + 0.1), (4.2, 2.3, 0.06), M["metal"], bevel=0.01))  # marco
for sx in (-1.4, 0.0, 1.4):
    panel_parts.append(box((sx, 0, PIV + 0.05), (0.08, 2.2, 0.06), M["dark"], bevel=0.0))  # nervios
for ix in range(6):
    for iy in range(3):
        panel_parts.append(box((-1.75 + ix * 0.7, -0.75 + iy * 0.75, PIV + 0.14), (0.66, 0.71, 0.02), M["solar"], bevel=0.0))
for p in panel_parts:
    parts.remove(p)
for x in bpy.context.selected_objects:
    x.select_set(False)
for p in panel_parts:
    p.select_set(True)
bpy.context.view_layer.objects.active = panel_parts[0]
bpy.ops.object.join()
panel = bpy.context.active_object
panel.name = "Anim_PanelMesh"
panel.parent = pivot
panel.location -= pivot.location
empty("Light_Status", (2.5, 0, 0.9))
export("solar_panel.glb", keep_separate=("Anim_",))

# =============================================================================
# Batería (banco de baterías con indicadores)
# =============================================================================
reset()
box((0, 0, 0.12), (2.0, 1.2, 0.24), M["hull2"], bevel=0.03)
for i in range(3):
    x = -0.62 + i * 0.62
    box((x, 0, 0.85), (0.52, 0.95, 1.2), M["hull"], bevel=0.05)
    box((x, -0.48, 1.25), (0.38, 0.02, 0.28), M["dark"], bevel=0.01)
    box((x, -0.495, 1.25), (0.3, 0.01, 0.06), M["cyan"], bevel=0.0, name=f"Charge{i}")
    box((x, 0, 1.48), (0.4, 0.8, 0.04), M["accent"], bevel=0.0)
for s in (-1, 1):
    box((s * 1.05, 0, 0.7), (0.06, 0.9, 0.9), M["dark"], bevel=0.01)          # radiadores laterales
empty("Light_Status", (0, -0.7, 1.6))
export("battery.glb")

# =============================================================================
# Generador de oxígeno (electrólisis de regolito fundido)
# =============================================================================
reset()
box((0, 0, 0.15), (2.6, 1.8, 0.3), M["hull2"], bevel=0.03)
cyl((-0.5, 0, 1.15), 0.6, 1.7, M["hull"], verts=32, bevel=0.04)               # reactor
sphere((-0.5, 0, 2.0), 0.6, M["hull"], scale=(1, 1, 0.5))
torus((-0.5, 0, 1.5), 0.62, 0.05, M["accent"])
box((-0.5, -0.6, 1.0), (0.3, 0.05, 0.3), M["warm"], bevel=0.02)              # mirilla incandescente
cyl((0.75, 0.35, 0.95), 0.32, 1.3, M["metal"], verts=24, bevel=0.03)          # tanques de O2
cyl((0.75, -0.35, 0.95), 0.32, 1.3, M["metal"], verts=24, bevel=0.03)
for y in (0.35, -0.35):
    sphere((0.75, y, 1.6), 0.32, M["metal"], scale=(1, 1, 0.5))
    torus((0.75, y, 1.2), 0.33, 0.03, M["cyan"])
strut((-0.1, 0, 1.6), (0.45, 0.35, 1.5), 0.05, M["metal"])
strut((-0.1, 0, 1.4), (0.45, -0.35, 1.3), 0.05, M["metal"])
box((-0.5, 0.75, 0.75), (0.8, 0.3, 0.7), M["regolith"], bevel=0.05)          # tolva de regolito
empty("Light_Status", (0.2, -0.9, 1.3))
export("oxygen_generator.glb")

# =============================================================================
# Extractor de agua (funde hielo y lo purifica)
# =============================================================================
reset()
box((0, 0, 0.15), (2.4, 1.8, 0.3), M["hull2"], bevel=0.03)
cyl((0.5, 0, 1.0), 0.7, 1.4, M["hull"], verts=32, bevel=0.04)
cyl((0.5, 0, 1.0), 0.45, 1.0, M["ice"], verts=24, bevel=0.0)
box((0.5, -0.68, 1.0), (0.3, 0.04, 0.9), M["glass"], bevel=0.02)
sphere((0.5, 0, 1.75), 0.7, M["hull"], scale=(1, 1, 0.4))
box((-0.65, 0, 0.8), (0.8, 1.1, 1.0), M["hull"], bevel=0.05)
for z in (0.55, 0.75, 0.95):
    box((-1.06, 0, z), (0.02, 0.9, 0.08), M["dark"], bevel=0.0)
cyl((-0.65, 0, 1.55), 0.12, 0.6, M["metal"], verts=16)
torus((0.5, 0, 0.45), 0.72, 0.04, M["accent"])
box((-0.65, -0.56, 1.1), (0.3, 0.02, 0.06), M["cyan"], bevel=0.0)
empty("Light_Status", (-0.65, -0.8, 1.4))
export("water_extractor.glb")
print("[structures] listo")
