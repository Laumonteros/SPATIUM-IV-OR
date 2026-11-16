class_name BuildableDef
extends GameDef
## Definición de una estructura construible (sección 9 del documento de diseño):
## modelo, costo, función, consumo/producción energética y radio de ocupación.

## Los valores nuevos se agregan al final: las partidas y los .tres guardan el número.
enum Role { SHELTER, SOLAR, BATTERY, OXYGEN, WATER, GREENHOUSE, LAB, WORKSHOP, COMMAND }

@export var role: Role = Role.SHELTER
@export var model: PackedScene
## Costo: id de recurso -> cantidad.
@export var cost: Dictionary[StringName, int] = {}
## Potencia nominal en kW: positiva = produce, negativa = consume.
@export var power_kw: float = 0.0
## Capacidad de almacenamiento eléctrico (kWh).
@export var storage_kwh: float = 0.0
## Radio que ocupa en el suelo (m), para validar la colocación.
@export var footprint_radius: float = 1.5
## Segundos que tarda la animación de construcción.
@export var build_time: float = 3.0
## Prioridad de suministro cuando falta energía (mayor = se apaga último).
@export var priority: int = 1
## Clave de traducción: qué hace (se muestra en el menú de construcción).
@export var function_key: String
## Fracción de la dosis de radiación que atraviesa el blindaje estando adentro
## (1 = sin blindaje). Valor de juego contextualizado: ver docs/fuentes_y_licencias.md.
@export var shield_factor: float = 1.0
## Script de módulo procedural (colonia preinstalada). Si está, reemplaza a `model`.
@export var module_script: Script
## Sector de la colonia al que pertenece (red eléctrica por sector).
@export var sector: StringName = &""
@export var science: ScienceSource


func cost_text() -> String:
	var parts: PackedStringArray = []
	for id: StringName in cost:
		var d := DataRegistry.get_def(id)
		parts.append("%d %s" % [cost[id], d.get_display_name() if d else String(id)])
	return ", ".join(parts)
