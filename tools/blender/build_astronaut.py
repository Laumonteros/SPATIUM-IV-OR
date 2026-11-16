"""SPATIUM IV — Astronauta (traje de exploración "SX-1").

Genera en Blender, por código y de forma reproducible:
  - el modelo (piezas rígidas de traje + uniones blandas), materiales PBR,
  - el esqueleto (nombres del perfil humanoide de Godot: compatible con retargeting de Mixamo),
  - animaciones propias del contexto espacial,
y exporta GLB para Godot + guarda el .blend fuente.

Uso:
  blender -b --factory-startup --python tools/blender/build_astronaut.py -- <raiz_repo> [--preview]

Convenciones: Z arriba, el personaje mira a -Y (frente de Blender). Escala 1 = 1 m.
Ejes locales de huesos (roll 0): en huesos verticales +X = flexión hacia adelante del tronco;
en piernas/brazos (apuntan hacia abajo) +X = balanceo hacia atrás, -X = hacia adelante.
"""
import math
import os
import sys

import bmesh
import bpy
from mathutils import Euler, Matrix, Quaternion, Vector

ARGS = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
ROOT = ARGS[0] if ARGS else os.getcwd()
PREVIEW = "--preview" in ARGS
FPS = 30

# ----------------------------------------------------------------------------
# Escena limpia
# ----------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene
scene.render.fps = FPS
scene.unit_settings.system = "METRIC"

# ----------------------------------------------------------------------------
# Materiales
# ----------------------------------------------------------------------------
def material(name, color, rough=0.6, metal=0.0, emission=None, strength=0.0, coat=0.0):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = m.node_tree.nodes.get("Principled BSDF")
    bsdf.inputs["Base Color"].default_value = (*color, 1.0)
    bsdf.inputs["Roughness"].default_value = rough
    bsdf.inputs["Metallic"].default_value = metal
    if coat > 0 and "Coat Weight" in bsdf.inputs:
        bsdf.inputs["Coat Weight"].default_value = coat
    if emission:
        bsdf.inputs["Emission Color"].default_value = (*emission, 1.0)
        bsdf.inputs["Emission Strength"].default_value = strength
    m.diffuse_color = (*color, 1.0)
    return m


def srgb(hexstr):
    h = hexstr.lstrip("#")
    c = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    return tuple(((x + 0.055) / 1.055) ** 2.4 if x > 0.04045 else x / 12.92 for x in c)


M = {
    "suit": material("SuitBeta", srgb("#E8E6E1"), rough=0.82),
    "suit_soft": material("SuitJoint", srgb("#C9C6BF"), rough=0.9),
    "hard": material("SuitHardShell", srgb("#F1F0EC"), rough=0.35, coat=0.3),
    "metal": material("BearingMetal", srgb("#A9AEB5"), rough=0.32, metal=1.0),
    "dark": material("RubberDark", srgb("#24272C"), rough=0.85),
    "accent": material("AccentSpatium", srgb("#FF8A3D"), rough=0.45),
    "visor": material("VisorGold", srgb("#C8923A"), rough=0.1, metal=1.0, coat=1.0),
    "glove": material("Glove", srgb("#B9BCC2"), rough=0.75),
    "panel": material("PanelGrey", srgb("#5D636B"), rough=0.5, metal=0.3),
    "light_white": material("LightWhite", (1, 1, 1), rough=0.2, emission=(1.0, 0.97, 0.9), strength=6.0),
    "light_cyan": material("LightCyan", srgb("#4FD1E8"), rough=0.2, emission=srgb("#4FD1E8"), strength=4.0),
    "light_orange": material("LightOrange", srgb("#FF8A3D"), rough=0.2, emission=srgb("#FF8A3D"), strength=4.0),
}

# ----------------------------------------------------------------------------
# Esqueleto (nombres del SkeletonProfileHumanoid de Godot)
# ----------------------------------------------------------------------------
BONES = {
    # nombre: (cabeza, cola, padre)
    "Hips": ((0, 0, 0.98), (0, 0, 1.10), None),
    "Spine": ((0, 0, 1.10), (0, 0, 1.22), "Hips"),
    "Chest": ((0, 0, 1.22), (0, 0, 1.36), "Spine"),
    "UpperChest": ((0, 0, 1.36), (0, 0, 1.48), "Chest"),
    "Neck": ((0, 0, 1.48), (0, 0, 1.56), "UpperChest"),
    "Head": ((0, 0, 1.56), (0, 0, 1.80), "Neck"),
}
for side, s in (("Left", 1.0), ("Right", -1.0)):
    BONES.update({
        f"{side}Shoulder": ((0.07 * s, 0, 1.44), (0.19 * s, 0, 1.44), "UpperChest"),
        f"{side}UpperArm": ((0.22 * s, 0, 1.42), (0.28 * s, 0.0, 1.14), f"{side}Shoulder"),
        f"{side}LowerArm": ((0.28 * s, 0.0, 1.14), (0.31 * s, -0.03, 0.88), f"{side}UpperArm"),
        f"{side}Hand": ((0.31 * s, -0.03, 0.88), (0.32 * s, -0.04, 0.76), f"{side}LowerArm"),
        f"{side}UpperLeg": ((0.11 * s, 0, 0.95), (0.12 * s, 0.01, 0.53), "Hips"),
        f"{side}LowerLeg": ((0.12 * s, 0.01, 0.53), (0.12 * s, 0.03, 0.12), f"{side}UpperLeg"),
        f"{side}Foot": ((0.12 * s, 0.03, 0.12), (0.12 * s, -0.11, 0.035), f"{side}LowerLeg"),
        f"{side}Toes": ((0.12 * s, -0.11, 0.035), (0.12 * s, -0.20, 0.035), f"{side}Foot"),
    })

arm_data = bpy.data.armatures.new("AstronautSkeleton")
arm_obj = bpy.data.objects.new("Astronaut", arm_data)
scene.collection.objects.link(arm_obj)
bpy.context.view_layer.objects.active = arm_obj
bpy.ops.object.mode_set(mode="EDIT")
for name, (head, tail, parent) in BONES.items():
    b = arm_data.edit_bones.new(name)
    b.head, b.tail, b.roll = Vector(head), Vector(tail), 0.0
for name, (_, _, parent) in BONES.items():
    if parent:
        b = arm_data.edit_bones[name]
        b.parent = arm_data.edit_bones[parent]
        b.use_connect = (Vector(BONES[parent][1]) - Vector(BONES[name][0])).length < 1e-4
bpy.ops.object.mode_set(mode="OBJECT")


def bone_point(name, t):
    h, tl, _ = BONES[name]
    return Vector(h).lerp(Vector(tl), t)


# ----------------------------------------------------------------------------
# Construcción de piezas
# ----------------------------------------------------------------------------
parts = []


def _finish(obj, mat, bone, bevel=0.0, subdiv=0, smooth=True, bevel_segments=3):
    obj.data.materials.append(mat)
    if bevel > 0:
        md = obj.modifiers.new("Bevel", "BEVEL")
        md.width = bevel
        md.segments = bevel_segments
        md.limit_method = "ANGLE"
    if subdiv > 0:
        md = obj.modifiers.new("Subsurf", "SUBSURF")
        md.levels = subdiv
        md.render_levels = subdiv
    bpy.context.view_layer.objects.active = obj
    for o in bpy.context.selected_objects:
        o.select_set(False)
    obj.select_set(True)
    bpy.ops.object.convert(target="MESH")
    if smooth:
        bpy.ops.object.shade_smooth_by_angle(angle=math.radians(40))
    vg = obj.vertex_groups.new(name=bone)
    vg.add(list(range(len(obj.data.vertices))), 1.0, "REPLACE")
    parts.append(obj)
    return obj


def _orient(obj, a, b):
    """Coloca un objeto creado a lo largo de Z entre los puntos a y b."""
    a, b = Vector(a), Vector(b)
    d = b - a
    obj.location = (a + b) / 2.0
    obj.rotation_euler = Vector((0, 0, 1)).rotation_difference(d.normalized()).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)


def box(name, loc, size, mat, bone, bevel=0.02, subdiv=0, rot=(0, 0, 0)):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc, rotation=rot)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=True)
    return _finish(o, mat, bone, bevel=bevel, subdiv=subdiv)


def rounded(name, loc, size, mat, bone, subdiv=1, bevel=0.0, rot=(0, 0, 0)):
    """Caja suavizada por subdivisión (formas orgánicas de traje)."""
    return box(name, loc, size, mat, bone, bevel=bevel, subdiv=subdiv, rot=rot)


def limb(name, a, b, r1, r2, mat, bone, verts=24, bevel=0.012):
    a, b = Vector(a), Vector(b)
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=(b - a).length)
    o = bpy.context.active_object
    o.name = name
    _orient(o, a, b)
    o.location = (a + b) / 2.0
    return _finish(o, mat, bone, bevel=bevel, bevel_segments=2)


def ring(name, center, axis, major, minor, mat, bone, seg=32):
    bpy.ops.mesh.primitive_torus_add(major_segments=seg, minor_segments=10, major_radius=major, minor_radius=minor)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.location = center
    return _finish(o, mat, bone)


def sphere(name, loc, radius, mat, bone, scale=(1, 1, 1), seg=24, rings=12):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=rings, radius=radius, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    return _finish(o, mat, bone)


def cyl(name, loc, radius, depth, mat, bone, axis=(0, 0, 1), verts=20, bevel=0.004):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=radius, depth=depth)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = Vector((0, 0, 1)).rotation_difference(Vector(axis).normalized()).to_euler()
    bpy.ops.object.transform_apply(location=False, rotation=True, scale=False)
    o.location = loc
    return _finish(o, mat, bone, bevel=bevel, bevel_segments=2)


def bellows(prefix, a, b, radius, count, mat, bone_a, bone_b):
    """Fuelle de unión blanda: anillos repartidos entre dos huesos."""
    a, b = Vector(a), Vector(b)
    axis = (b - a).normalized()
    for i in range(count):
        t = (i + 0.5) / count
        ring(f"{prefix}_{i}", a.lerp(b, t), axis, radius, radius * 0.22, mat, bone_a if t < 0.5 else bone_b, seg=24)


# --- Torso duro (HUT) y pelvis ----------------------------------------------
rounded("Torso", (0, -0.005, 1.31), (0.46, 0.30, 0.36), M["suit"], "Chest", subdiv=2, bevel=0.06)
rounded("ChestPlate", (0, -0.135, 1.33), (0.34, 0.08, 0.24), M["hard"], "Chest", subdiv=1, bevel=0.03)
rounded("Abdomen", (0, 0, 1.15), (0.38, 0.26, 0.16), M["suit_soft"], "Spine", subdiv=1, bevel=0.04)
ring("WaistBearing", (0, 0, 1.08), (0, 0, 1), 0.2, 0.022, M["metal"], "Hips", seg=40)
rounded("Pelvis", (0, 0.005, 0.98), (0.40, 0.27, 0.18), M["suit"], "Hips", subdiv=1, bevel=0.05)
box("BeltAccent", (0, -0.13, 1.03), (0.30, 0.02, 0.035), M["accent"], "Hips", bevel=0.008)
# Módulo de pecho (DCM): controles del soporte vital
box("DCM", (0, -0.2, 1.24), (0.22, 0.07, 0.12), M["panel"], "Chest", bevel=0.012)
for i, x in enumerate((-0.065, 0.0, 0.065)):
    cyl(f"DCMKnob{i}", (x, -0.24, 1.255), 0.016, 0.02, M["metal"], "Chest", axis=(0, 1, 0), verts=16)
box("DCMDisplay", (0.0, -0.236, 1.215), (0.16, 0.006, 0.035), M["light_cyan"], "Chest", bevel=0.0)
box("ChestStripeL", (0.12, -0.155, 1.43), (0.07, 0.012, 0.025), M["accent"], "UpperChest", bevel=0.004)
box("ChestStripeR", (-0.12, -0.155, 1.43), (0.07, 0.012, 0.025), M["accent"], "UpperChest", bevel=0.004)
# Parche de misión (diseño propio, sin logos de NASA)
cyl("MissionPatch", (0.13, -0.158, 1.36), 0.035, 0.006, M["accent"], "Chest", axis=(0, 1, 0), verts=24, bevel=0.0)
cyl("MissionPatchCore", (0.13, -0.162, 1.36), 0.022, 0.004, M["dark"], "Chest", axis=(0, 1, 0), verts=24, bevel=0.0)

# --- Mochila de soporte vital (PLSS) -----------------------------------------
rounded("PLSS", (0, 0.27, 1.30), (0.44, 0.22, 0.56), M["hard"], "UpperChest", subdiv=2, bevel=0.05)
box("PLSSFrame", (0, 0.39, 1.30), (0.36, 0.04, 0.46), M["panel"], "UpperChest", bevel=0.015)
for i, z in enumerate((1.12, 1.18, 1.24)):
    box(f"PLSSVent{i}", (0, 0.415, z), (0.24, 0.012, 0.02), M["dark"], "UpperChest", bevel=0.004)
box("PLSSStripe", (0, 0.40, 1.47), (0.30, 0.03, 0.04), M["accent"], "UpperChest", bevel=0.008)
for x in (-0.19, 0.19):
    box(f"PLSSLight{'L' if x > 0 else 'R'}", (x, 0.30, 1.56), (0.03, 0.06, 0.03), M["light_orange"], "UpperChest", bevel=0.006)
# Antena de comunicaciones
cyl("Antenna", (0.16, 0.33, 1.68), 0.006, 0.22, M["metal"], "UpperChest", verts=10)
sphere("AntennaTip", (0.16, 0.33, 1.795), 0.012, M["light_orange"], "UpperChest", seg=12, rings=6)
# Herramienta acoplada a la cadera (multiherramienta en su funda)
box("ToolHolster", (-0.235, -0.01, 0.98), (0.05, 0.11, 0.16), M["panel"], "Hips", bevel=0.01)
cyl("ToolGrip", (-0.235, -0.01, 1.08), 0.018, 0.08, M["dark"], "Hips", verts=12)

# --- Cuello y casco ------------------------------------------------------------
ring("NeckRing", (0, -0.01, 1.50), (0, -0.25, 1), 0.15, 0.024, M["metal"], "UpperChest", seg=40)
sphere("HelmetShell", (0, -0.01, 1.66), 0.175, M["hard"], "Head", scale=(1.0, 1.04, 1.02), seg=40, rings=20)
# Visor: casquete frontal ligeramente mayor que el casco
bpy.ops.mesh.primitive_uv_sphere_add(segments=48, ring_count=24, radius=0.186, location=(0, -0.024, 1.665))
visor = bpy.context.active_object
visor.name = "Visor"
visor.scale = (1.0, 1.04, 1.0)
bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
bm = bmesh.new()
bm.from_mesh(visor.data)
cut = [v for v in bm.verts if v.co.y > -0.045 or v.co.z < -0.105 or v.co.z > 0.115 or abs(v.co.x) > 0.158]
bmesh.ops.delete(bm, geom=cut, context="VERTS")
bmesh.ops.solidify(bm, geom=bm.faces[:], thickness=0.004)
bm.to_mesh(visor.data)
bm.free()
print(f"[astronaut] visor verts: {len(visor.data.vertices)}")
_finish(visor, M["visor"], "Head")
# Protector del visor (EVVA) y luces del casco
ring("VisorBrim", (0, -0.03, 1.668), (0, -1, 0.0), 0.172, 0.012, M["metal"], "Head", seg=40)
for x in (-0.175, 0.175):
    side = "L" if x > 0 else "R"
    box(f"HelmetLamp{side}", (x, -0.06, 1.70), (0.045, 0.09, 0.05), M["panel"], "Head", bevel=0.01)
    cyl(f"HelmetLampLens{side}", (x, -0.108, 1.70), 0.017, 0.012, M["light_white"], "Head", axis=(0, 1, 0), verts=16)
    cyl(f"HelmetCam{side}", (x, -0.02, 1.62), 0.012, 0.03, M["dark"], "Head", axis=(0, 1, 0), verts=12)
# Micrófono/comunicaciones
box("CommsPod", (-0.17, 0.02, 1.58), (0.03, 0.06, 0.05), M["accent"], "Head", bevel=0.008)

# --- Brazos ----------------------------------------------------------------
for side, s in (("Left", 1.0), ("Right", -1.0)):
    sh = bone_point(f"{side}UpperArm", 0.0)
    el = bone_point(f"{side}LowerArm", 0.0)
    wr = bone_point(f"{side}Hand", 0.0)
    rounded(f"{side}ShoulderPad", (0.215 * s, 0.0, 1.43), (0.15, 0.20, 0.13), M["suit"], f"{side}Shoulder", subdiv=1, bevel=0.04)
    ring(f"{side}ShoulderBearing", sh + Vector((0.005 * s, 0, -0.03)), (s, 0, -0.35), 0.075, 0.016, M["metal"], f"{side}UpperArm")
    limb(f"{side}UpperArmShell", sh + Vector((0, 0, -0.04)), el + Vector((0, 0, 0.03)), 0.072, 0.063, M["suit"], f"{side}UpperArm")
    box(f"{side}ArmStripe", bone_point(f"{side}UpperArm", 0.35) + Vector((0.065 * s, 0, 0)), (0.012, 0.07, 0.03), M["accent"], f"{side}UpperArm", bevel=0.004)
    sphere(f"{side}Elbow", el, 0.066, M["suit_soft"], f"{side}LowerArm", seg=20, rings=10)
    limb(f"{side}ForearmShell", el + Vector((0, 0, -0.02)), wr + Vector((0, 0, 0.03)), 0.062, 0.05, M["suit"], f"{side}LowerArm")
    ring(f"{side}WristBearing", wr + Vector((0, 0, 0.02)), Vector(BONES[f"{side}LowerArm"][1]) - Vector(BONES[f"{side}LowerArm"][0]), 0.052, 0.012, M["metal"], f"{side}LowerArm")
    # Guante: palma, dedos (bloque segmentado) y pulgar
    hand_dir = (Vector(BONES[f"{side}Hand"][1]) - Vector(BONES[f"{side}Hand"][0])).normalized()
    palm_c = bone_point(f"{side}Hand", 0.45)
    rounded(f"{side}Palm", palm_c, (0.07, 0.105, 0.11), M["glove"], f"{side}Hand", subdiv=1, bevel=0.012)
    for i in range(4):
        y = -0.036 + i * 0.024
        limb(f"{side}Finger{i}", palm_c + Vector((0, y - 0.005, -0.045)), palm_c + Vector((0.004 * s, y - 0.012, -0.125 + abs(i - 1.5) * 0.01)), 0.0165, 0.0135, M["glove"], f"{side}Hand", verts=10, bevel=0.0)
    limb(f"{side}Thumb", palm_c + Vector((-0.008 * s, -0.05, 0.0)), palm_c + Vector((-0.02 * s, -0.095, -0.05)), 0.018, 0.015, M["glove"], f"{side}Hand", verts=10, bevel=0.0)
    cyl(f"{side}GloveCuff", wr + Vector((0, 0, -0.005)), 0.06, 0.05, M["dark"], f"{side}Hand", axis=Vector(BONES[f"{side}Hand"][1]) - Vector(BONES[f"{side}Hand"][0]), verts=20)

# Pantalla de muñeca (brazo izquierdo): interfaz del escáner
lw = bone_point("LeftLowerArm", 0.6)
box("WristComputer", lw + Vector((0.0, -0.055, 0.0)), (0.07, 0.03, 0.09), M["panel"], "LeftLowerArm", bevel=0.008)
box("WristScreen", lw + Vector((0.0, -0.072, 0.005)), (0.055, 0.004, 0.065), M["light_cyan"], "LeftLowerArm", bevel=0.0)

# --- Piernas ---------------------------------------------------------------
for side, s in (("Left", 1.0), ("Right", -1.0)):
    hp = bone_point(f"{side}UpperLeg", 0.0)
    kn = bone_point(f"{side}LowerLeg", 0.0)
    an = bone_point(f"{side}Foot", 0.0)
    ring(f"{side}HipBearing", hp + Vector((0, 0, -0.05)), (0.15 * s, 0, 1), 0.09, 0.016, M["metal"], f"{side}UpperLeg")
    limb(f"{side}ThighShell", hp + Vector((0, 0, -0.06)), kn + Vector((0, 0, 0.04)), 0.092, 0.075, M["suit"], f"{side}UpperLeg")
    box(f"{side}ThighPocket", bone_point(f"{side}UpperLeg", 0.45) + Vector((0.075 * s, -0.01, 0)), (0.03, 0.10, 0.12), M["suit_soft"], f"{side}UpperLeg", bevel=0.012)
    sphere(f"{side}Knee", kn, 0.078, M["suit_soft"], f"{side}LowerLeg", seg=20, rings=10)
    rounded(f"{side}KneePad", kn + Vector((0, -0.06, 0.0)), (0.09, 0.04, 0.10), M["hard"], f"{side}LowerLeg", subdiv=1, bevel=0.015)
    limb(f"{side}CalfShell", kn + Vector((0, 0, -0.03)), an + Vector((0, 0, 0.1)), 0.075, 0.068, M["suit"], f"{side}LowerLeg")
    box(f"{side}CalfStripe", bone_point(f"{side}LowerLeg", 0.3) + Vector((0.07 * s, 0, 0)), (0.012, 0.06, 0.03), M["accent"], f"{side}LowerLeg", bevel=0.004)
    # Bota
    rounded(f"{side}BootUpper", an + Vector((0, -0.01, 0.04)), (0.13, 0.15, 0.13), M["suit_soft"], f"{side}Foot", subdiv=1, bevel=0.02)
    rounded(f"{side}Boot", an + Vector((0, -0.07, -0.05)), (0.13, 0.27, 0.09), M["hard"], f"{side}Foot", subdiv=1, bevel=0.02)
    box(f"{side}Sole", an + Vector((0, -0.07, -0.095)), (0.135, 0.28, 0.03), M["dark"], f"{side}Foot", bevel=0.01)
    rounded(f"{side}ToeCap", Vector(BONES[f"{side}Toes"][0]) + Vector((0, -0.04, 0.0)), (0.12, 0.09, 0.07), M["hard"], f"{side}Toes", subdiv=1, bevel=0.015)
    box(f"{side}ToeSole", Vector(BONES[f"{side}Toes"][0]) + Vector((0, -0.04, -0.045)), (0.125, 0.10, 0.03), M["dark"], f"{side}Toes", bevel=0.01)
    ring(f"{side}AnkleRing", an + Vector((0, 0.0, 0.11)), (0, 0, 1), 0.072, 0.012, M["accent"], f"{side}LowerLeg")

# ----------------------------------------------------------------------------
# Unir piezas en una malla con piel rígida por hueso
# ----------------------------------------------------------------------------
for o in bpy.context.selected_objects:
    o.select_set(False)
for o in parts:
    o.select_set(True)
bpy.context.view_layer.objects.active = parts[0]
bpy.ops.object.join()
body = bpy.context.active_object
body.name = "AstronautSuit"
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
# Optimización: decimado (colapso) conservando bordes y grupos de vértices
dec = body.modifiers.new("Decimate", "DECIMATE")
dec.decimate_type = "COLLAPSE"
dec.ratio = 0.62
dec.use_collapse_triangulate = False
bpy.context.view_layer.objects.active = body
bpy.ops.object.modifier_apply(modifier="Decimate")
body.parent = arm_obj
mod = body.modifiers.new("Armature", "ARMATURE")
mod.object = arm_obj
tri_count = sum(len(p.vertices) - 2 for p in body.data.polygons)  # tras decimar

# ----------------------------------------------------------------------------
# Animaciones
# ----------------------------------------------------------------------------
bpy.context.view_layer.objects.active = arm_obj
arm_obj.animation_data_create()
for pb in arm_obj.pose.bones:
    pb.rotation_mode = "QUATERNION"


def make_action(name, length, keys, loop=True):
    """keys: {frame: {hueso: (rx, ry, rz) grados | ("loc", (x, y, z))}}"""
    act = bpy.data.actions.new(name)
    act.use_fake_user = True
    arm_obj.animation_data.action = act
    frames = sorted(keys)
    used_bones = {b for f in frames for b in keys[f] if not b.endswith("@loc")}
    used_locs = {b[:-4] for f in frames for b in keys[f] if b.endswith("@loc")}
    for f in frames:
        scene.frame_set(f)
        for bname in used_bones:
            rot = keys[f].get(bname)
            if rot is None:
                rot = _interp(keys, f, bname)
            pb = arm_obj.pose.bones[bname]
            pb.rotation_quaternion = Euler([math.radians(a) for a in rot], "XYZ").to_quaternion()
            pb.keyframe_insert("rotation_quaternion", frame=f)
        for bname in used_locs:
            loc = keys[f].get(bname + "@loc")
            if loc is None:
                loc = _interp(keys, f, bname + "@loc")
            pb = arm_obj.pose.bones[bname]
            pb.location = loc
            pb.keyframe_insert("location", frame=f)
    if loop:
        # El último fotograma repite el primero: ciclo continuo
        pass
    act.frame_range = (frames[0], frames[-1])
    # Interpolación suave
    for fc in _fcurves(act):
        for kp in fc.keyframe_points:
            kp.interpolation = "BEZIER"
            kp.easing = "AUTO"
    for pb in arm_obj.pose.bones:
        pb.rotation_quaternion = Quaternion()
        pb.location = (0, 0, 0)
    return act


def _fcurves(act):
    if hasattr(act, "fcurves") and len(getattr(act, "fcurves", [])) > 0:
        return list(act.fcurves)
    out = []
    for layer in getattr(act, "layers", []):
        for strip in layer.strips:
            for bag in strip.channelbags:
                out.extend(bag.fcurves)
    return out


def _interp(keys, f, bname):
    """Valor de un hueso no definido en este fotograma: interpola entre vecinos."""
    frames = sorted(k for k in keys if bname in keys[k])
    if not frames:
        return (0, 0, 0)
    prev = max((k for k in frames if k <= f), default=frames[0])
    nxt = min((k for k in frames if k >= f), default=frames[-1])
    if prev == nxt:
        return keys[prev][bname]
    t = (f - prev) / (nxt - prev)
    a, b = keys[prev][bname], keys[nxt][bname]
    return tuple(x + (y - x) * t for x, y in zip(a, b))


def mirror(pose):
    """Intercambia lado izquierdo/derecho de una pose (invierte giros Y/Z)."""
    out = {}
    for k, v in pose.items():
        nk = k.replace("Left", "§").replace("Right", "Left").replace("§", "Right")
        if k.endswith("@loc"):
            out[nk] = (-v[0], v[1], v[2])
        else:
            out[nk] = (v[0], -v[1], -v[2])
    return out


# Reposo con brazos relajados (los brazos del esqueleto están en pose A)
REST = {
    "LeftUpperArm": (-4, 0, -6), "RightUpperArm": (-4, 0, 6),
    "LeftLowerArm": (-18, 0, 0), "RightLowerArm": (-18, 0, 0),
    "Spine": (2, 0, 0), "Chest": (0, 0, 0), "Neck": (0, 0, 0), "Head": (0, 0, 0),
}


def pose(**kw):
    p = dict(REST)
    for k, v in kw.items():
        p[k.replace("__", "@")] = v
    return p


# Reposo: respiración (el pecho se eleva) y leve balanceo del peso
idle = {
    0: pose(Chest=(0, 0, 0), UpperChest=(0, 0, 0), Hips__loc=(0, 0, 0), Head=(0, 0, 0)),
    45: pose(Chest=(-2.2, 0, 0), UpperChest=(-1.2, 0, 0), Hips__loc=(0, 0.006, 0), Head=(2, 3, 0),
             LeftUpperArm=(-5, 0, -8), RightUpperArm=(-5, 0, 8)),
    90: pose(Chest=(0, 0, 0), UpperChest=(0, 0, 0), Hips__loc=(0, 0, 0), Head=(0, -2, 0)),
    120: pose(Chest=(0, 0, 0), UpperChest=(0, 0, 0), Hips__loc=(0, 0, 0), Head=(0, 0, 0)),
}

# Caminata lunar: ritmo lento, pasos largos y algo de rebote (ciclo de 40 fotogramas)
w_contact = pose(LeftUpperLeg=(-24, 0, 0), RightUpperLeg=(18, 0, 0), LeftLowerLeg=(6, 0, 0), RightLowerLeg=(18, 0, 0),
                 LeftFoot=(-12, 0, 0), RightFoot=(14, 0, 0), LeftUpperArm=(14, 0, -7), RightUpperArm=(-16, 0, 7),
                 Spine=(6, 0, 0), Chest=(0, -4, 0), Hips__loc=(0, -0.015, 0), Hips=(0, 4, 0))
w_pass = pose(LeftUpperLeg=(0, 0, 0), RightUpperLeg=(-12, 0, 0), LeftLowerLeg=(4, 0, 0), RightLowerLeg=(42, 0, 0),
              LeftFoot=(0, 0, 0), RightFoot=(-6, 0, 0), LeftUpperArm=(0, 0, -7), RightUpperArm=(0, 0, 7),
              Spine=(6, 0, 0), Chest=(0, 0, 0), Hips__loc=(0, 0.03, 0), Hips=(0, 0, 0))
walk = {0: w_contact, 10: w_pass, 20: mirror(w_contact), 30: mirror(w_pass), 40: w_contact}

# Trote lunar ("lope"): impulso con ambas piernas y fase de vuelo larga (ciclo de 30 fotogramas)
r_push = pose(LeftUpperLeg=(-38, 0, 0), RightUpperLeg=(26, 0, 0), LeftLowerLeg=(24, 0, 0), RightLowerLeg=(34, 0, 0),
              LeftFoot=(-6, 0, 0), RightFoot=(22, 0, 0), LeftUpperArm=(26, 0, -10), RightUpperArm=(-30, 0, 10),
              LeftLowerArm=(-40, 0, 0), RightLowerArm=(-40, 0, 0), Spine=(20, 0, 0), Chest=(6, -6, 0),
              Hips__loc=(0, -0.03, 0), Hips=(0, 6, 0))
r_flight = pose(LeftUpperLeg=(-18, 0, 0), RightUpperLeg=(-4, 0, 0), LeftLowerLeg=(30, 0, 0), RightLowerLeg=(62, 0, 0),
                LeftFoot=(-4, 0, 0), RightFoot=(8, 0, 0), LeftUpperArm=(8, 0, -14), RightUpperArm=(-10, 0, 14),
                LeftLowerArm=(-42, 0, 0), RightLowerArm=(-42, 0, 0), Spine=(20, 0, 0), Chest=(6, 0, 0),
                Hips__loc=(0, 0.06, 0), Hips=(0, 0, 0))
run = {0: r_push, 8: r_flight, 15: mirror(r_push), 23: mirror(r_flight), 30: r_push}

# Salto: agacharse e impulsarse
crouch = pose(LeftUpperLeg=(-48, 0, 0), RightUpperLeg=(-48, 0, 0), LeftLowerLeg=(82, 0, 0), RightLowerLeg=(82, 0, 0),
              LeftFoot=(-30, 0, 0), RightFoot=(-30, 0, 0), Spine=(18, 0, 0), Chest=(8, 0, 0),
              LeftUpperArm=(30, 0, -10), RightUpperArm=(30, 0, 10), Hips__loc=(0, -0.2, 0))
extend = pose(LeftUpperLeg=(-6, 0, 0), RightUpperLeg=(4, 0, 0), LeftLowerLeg=(8, 0, 0), RightLowerLeg=(14, 0, 0),
              LeftFoot=(18, 0, 0), RightFoot=(18, 0, 0), Spine=(2, 0, 0), Chest=(-4, 0, 0),
              LeftUpperArm=(-42, 0, -16), RightUpperArm=(-42, 0, 16), Hips__loc=(0, 0.02, 0))
jump_start = {0: pose(Hips__loc=(0, 0, 0)), 5: crouch, 10: extend}

# En el aire: piernas recogidas y brazos abiertos buscando equilibrio
air_a = pose(LeftUpperLeg=(-28, 0, 0), RightUpperLeg=(-8, 0, 0), LeftLowerLeg=(40, 0, 0), RightLowerLeg=(30, 0, 0),
             LeftFoot=(10, 0, 0), RightFoot=(10, 0, 0), LeftUpperArm=(-10, 0, -32), RightUpperArm=(-6, 0, 30),
             LeftLowerArm=(-30, 0, 0), RightLowerArm=(-26, 0, 0), Spine=(4, 0, 0), Hips__loc=(0, 0, 0))
air_b = pose(LeftUpperLeg=(-20, 0, 0), RightUpperLeg=(-16, 0, 0), LeftLowerLeg=(34, 0, 0), RightLowerLeg=(38, 0, 0),
             LeftFoot=(10, 0, 0), RightFoot=(10, 0, 0), LeftUpperArm=(-6, 0, -36), RightUpperArm=(-10, 0, 34),
             LeftLowerArm=(-26, 0, 0), RightLowerArm=(-30, 0, 0), Spine=(4, 0, 0), Hips__loc=(0, 0, 0))
fall = {0: air_a, 20: air_b, 40: air_a}

# Aterrizaje: absorber el impacto y recuperar la postura
land_low = pose(LeftUpperLeg=(-40, 0, 0), RightUpperLeg=(-36, 0, 0), LeftLowerLeg=(70, 0, 0), RightLowerLeg=(66, 0, 0),
                LeftFoot=(-26, 0, 0), RightFoot=(-24, 0, 0), Spine=(16, 0, 0), Chest=(6, 0, 0),
                LeftUpperArm=(-16, 0, -22), RightUpperArm=(-16, 0, 22), Hips__loc=(0, -0.16, 0))
land = {0: air_a, 4: land_low, 16: pose(Hips__loc=(0, 0, 0))}

# Recolectar: agacharse, alcanzar el suelo con la mano derecha y guardar en el traje
reach = pose(LeftUpperLeg=(-62, 0, -4), RightUpperLeg=(-20, 0, 6), LeftLowerLeg=(96, 0, 0), RightLowerLeg=(64, 0, 0),
             LeftFoot=(-34, 0, 0), RightFoot=(-30, 0, 0), Spine=(26, 0, 0), Chest=(16, 0, 0), Neck=(10, 0, 0), Head=(14, 0, 0),
             RightUpperArm=(-58, 0, 12), RightLowerArm=(-14, 0, 0), RightHand=(-20, 0, 0),
             LeftUpperArm=(-8, 0, -18), LeftLowerArm=(-40, 0, 0), Hips__loc=(0, -0.3, -0.05))
grab = dict(reach)
grab.update({"RightHand": (10, 0, 0), "RightLowerArm": (-24, 0, 0)})
lift = pose(LeftUpperLeg=(-24, 0, 0), RightUpperLeg=(-8, 0, 0), LeftLowerLeg=(36, 0, 0), RightLowerLeg=(20, 0, 0),
            Spine=(10, 0, 0), Chest=(4, 0, 0), RightUpperArm=(-30, 0, 18), RightLowerArm=(-96, 0, 0),
            Hips__loc=(0, -0.08, 0))
collect = {0: pose(Hips__loc=(0, 0, 0)), 14: reach, 24: grab, 38: lift, 54: pose(Hips__loc=(0, 0, 0))}

# Escanear: levantar la computadora de muñeca y mirarla
scan_up = pose(LeftUpperArm=(-52, 0, 10), LeftLowerArm=(-95, 0, 0), LeftHand=(0, 0, 0),
               Head=(16, -12, 0), Neck=(6, 0, 0), Chest=(0, -8, 0))
scan = {0: pose(), 10: scan_up, 36: scan_up, 46: pose()}

# Interactuar: presionar un control al frente
press = pose(RightUpperArm=(-62, 0, 4), RightLowerArm=(-30, 0, 0), RightHand=(-10, 0, 0), Spine=(6, 0, 0), Head=(8, 0, 0))
interact = {0: pose(), 8: press, 16: press, 26: pose()}

# Agachado: rodillas flexionadas, torso inclinado (reposo y caminata agachada)
crouch_pose = pose(LeftUpperLeg=(-52, 0, -4), RightUpperLeg=(-52, 0, 4), LeftLowerLeg=(88, 0, 0), RightLowerLeg=(88, 0, 0),
                   LeftFoot=(-34, 0, 0), RightFoot=(-34, 0, 0), Spine=(16, 0, 0), Chest=(8, 0, 0), Head=(-8, 0, 0),
                   LeftUpperArm=(-14, 0, -12), RightUpperArm=(-14, 0, 12), LeftLowerArm=(-36, 0, 0), RightLowerArm=(-36, 0, 0),
                   Hips__loc=(0, -0.32, 0))
crouch_b = dict(crouch_pose)
crouch_b.update({"Chest": (6, 0, 0), "Hips@loc": (0, -0.33, 0)})
crouch = {0: crouch_pose, 45: crouch_b, 90: crouch_pose}
cw_a = dict(crouch_pose)
cw_a.update({"LeftUpperLeg": (-70, 0, -4), "RightUpperLeg": (-34, 0, 4), "LeftLowerLeg": (96, 0, 0), "RightLowerLeg": (80, 0, 0),
             "LeftUpperArm": (6, 0, -12), "RightUpperArm": (-26, 0, 12)})
cw_b = mirror(cw_a)
crouch_walk = {0: cw_a, 20: cw_b, 40: cw_a}

CLIPS = [
    ("Idle", idle, True), ("Walk", walk, True), ("Run", run, True), ("JumpStart", jump_start, False),
    ("Fall", fall, True), ("Land", land, False), ("Collect", collect, False), ("Scan", scan, False),
    ("Interact", interact, False), ("Crouch", crouch, True), ("CrouchWalk", crouch_walk, True),
]
for name, keys, loop in CLIPS:
    make_action(name, max(keys), keys, loop)
arm_obj.animation_data.action = bpy.data.actions["Idle"]

# ----------------------------------------------------------------------------
# Guardar fuente y exportar GLB
# ----------------------------------------------------------------------------
blend_path = os.path.join(ROOT, "art_source", "blender", "astronaut.blend")
glb_path = os.path.join(ROOT, "game", "assets", "models", "characters", "astronaut", "astronaut.glb")
os.makedirs(os.path.dirname(blend_path), exist_ok=True)
os.makedirs(os.path.dirname(glb_path), exist_ok=True)
bpy.ops.wm.save_as_mainfile(filepath=blend_path)

for o in bpy.context.selected_objects:
    o.select_set(False)
arm_obj.select_set(True)
body.select_set(True)
bpy.ops.export_scene.gltf(
    filepath=glb_path,
    export_format="GLB",
    use_selection=True,
    export_apply=True,
    export_animations=True,
    export_animation_mode="ACTIONS",
    export_force_sampling=True,
    export_frame_range=False,
    export_skins=True,
    export_yup=True,
)
print(f"[astronaut] triangulos aprox: {tri_count}, huesos: {len(BONES)}, animaciones: {len(CLIPS)}")
print(f"[astronaut] {glb_path}")

# ----------------------------------------------------------------------------
# Vista previa (render de control)
# ----------------------------------------------------------------------------
if PREVIEW:
    prev_dir = ARGS[ARGS.index("--preview") + 1] if len(ARGS) > ARGS.index("--preview") + 1 else os.path.join(ROOT, "art_source")
    cam_data = bpy.data.cameras.new("Cam")
    cam = bpy.data.objects.new("Cam", cam_data)
    scene.collection.objects.link(cam)
    scene.camera = cam
    cam_data.lens = 55
    sun_d = bpy.data.lights.new("Sun", "SUN")
    sun_d.energy = 4.0
    sun_o = bpy.data.objects.new("Sun", sun_d)
    sun_o.rotation_euler = (math.radians(50), 0, math.radians(35))
    scene.collection.objects.link(sun_o)
    world = bpy.data.worlds.new("W")
    world.use_nodes = True
    world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.055, 0.07, 1)
    world.node_tree.nodes["Background"].inputs[1].default_value = 1.0
    scene.world = world
    scene.render.engine = "BLENDER_EEVEE" if "BLENDER_EEVEE" in [e.identifier for e in bpy.types.RenderSettings.bl_rna.properties["engine"].enum_items] else "BLENDER_WORKBENCH"
    scene.render.resolution_x, scene.render.resolution_y = 900, 900
    scene.render.film_transparent = False
    shots = [("front", (0.0, -3.6, 1.15), "Idle", 1), ("back34", (2.6, 2.6, 1.4), "Idle", 1),
             ("walk", (3.2, -1.6, 1.1), "Walk", 10), ("run", (3.2, -1.6, 1.1), "Run", 8),
             ("collect", (2.6, -2.6, 1.1), "Collect", 24), ("scan", (1.6, -2.8, 1.5), "Scan", 20),
             ("jump", (3.2, -1.6, 1.1), "JumpStart", 5)]
    for tag, pos, clip, frame in shots:
        cam.location = pos
        direction = Vector((0, 0, 1.0)) - Vector(pos)
        cam.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()
        arm_obj.animation_data.action = bpy.data.actions[clip]
        scene.frame_set(frame)
        scene.render.filepath = os.path.join(prev_dir, f"astro_{tag}.png")
        bpy.ops.render.render(write_still=True)
    print("[astronaut] previews listos")
