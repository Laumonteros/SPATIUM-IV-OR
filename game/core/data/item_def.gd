class_name ItemDef
extends GameDef
## Definición de un recurso o ítem recolectable/fabricable.
## Cubre los campos de la sección 8 del documento de diseño: nombre,
## descripción, utilidad, valor científico/de fabricación, modelo y ubicación.

enum Category { RAW_MATERIAL, ICE, SAMPLE, SPECIAL_MINERAL, CONSUMABLE, COMPONENT }

@export var category: Category = Category.RAW_MATERIAL
## Cantidad máxima por casillero de inventario.
@export_range(1, 999) var max_stack: int = 50
## Masa por unidad, en kg (afecta la carga del traje).
@export_range(0.0, 500.0, 0.1) var unit_mass_kg: float = 1.0
## Clave de traducción: para qué sirve.
@export var utility_key: String
## Clave de traducción: dónde suele encontrarse.
@export var location_key: String
@export_range(0, 100) var scientific_value: int = 0
@export_range(0, 100) var fabrication_value: int = 0
## Modelo 3D del recurso en el mundo / al soltarlo.
@export var world_scene: PackedScene
## Respaldo científico de la descripción (composición, abundancia, etc.).
@export var science: ScienceSource
