class_name GameDef
extends Resource
## Base de toda definición de contenido (recursos, estructuras, misiones...).
##
## Las definiciones son datos (`.tres` en `res://data/`), no código: agregar
## contenido no requiere tocar scripts. `DataRegistry` las indexa por `id`.

## Identificador único y estable (se usa en partidas guardadas: no renombrar).
@export var id: StringName
## Clave de traducción del nombre (p. ej. "ITEM_IRON_NAME").
@export var name_key: String
## Clave de traducción de la descripción.
@export var description_key: String
@export var icon: Texture2D


func get_display_name() -> String:
	return tr(name_key) if name_key != "" else String(id)


func get_description() -> String:
	return tr(description_key) if description_key != "" else ""
