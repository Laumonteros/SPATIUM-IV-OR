class_name ScienceSource
extends Resource
## Referencia científica de un dato mostrado en el juego.
##
## Regla del proyecto: los datos reales se distinguen siempre de los valores
## simplificados para equilibrar el juego. La interfaz muestra fuente, fecha y
## unidades, y etiqueta como "valor de juego" todo lo que no es una medición.

enum Kind {
	## Medición o dato publicado por una fuente oficial.
	REAL_DATA,
	## Valor real redondeado o escalado para el juego (se explica cómo).
	ADAPTED,
	## Valor inventado para equilibrar la jugabilidad.
	GAMEPLAY_VALUE,
}

@export var kind: Kind = Kind.GAMEPLAY_VALUE
## Organismo o conjunto de datos (p. ej. "NASA DONKI", "LRO LOLA").
@export var source_name: String
@export var url: String
## Fecha de publicación u obtención del dato, ISO 8601 (AAAA-MM-DD).
@export var date: String
@export var units: String
## Explicación breve: qué representa y, si es ADAPTED, cómo se ajustó.
@export_multiline var notes: String


func is_real() -> bool:
	return kind == Kind.REAL_DATA


func get_kind_label() -> String:
	match kind:
		Kind.REAL_DATA: return tr("SCIENCE_KIND_REAL")
		Kind.ADAPTED: return tr("SCIENCE_KIND_ADAPTED")
		_: return tr("SCIENCE_KIND_GAMEPLAY")
