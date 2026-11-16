extends Node
## Índice de todas las definiciones de contenido (`GameDef`) en `res://data/`.
##
## Se construye una vez al iniciar. Consultas: `get_def(&"iron")`,
## `get_all_of(ItemDef)`. Los ids deben ser únicos en todo el proyecto.

const DATA_ROOT := "res://data"

var _by_id: Dictionary[StringName, GameDef] = {}


func _ready() -> void:
	rebuild()


func rebuild(root: String = DATA_ROOT) -> void:
	_by_id.clear()
	_scan_dir(root)


func has_def(id: StringName) -> bool:
	return _by_id.has(id)


func get_def(id: StringName) -> GameDef:
	return _by_id.get(id)


## Devuelve todas las definiciones cuyo script hereda de `type` (p. ej. ItemDef).
func get_all_of(type: Script) -> Array[GameDef]:
	var out: Array[GameDef] = []
	for def: GameDef in _by_id.values():
		var s: Script = def.get_script()
		while s:
			if s == type:
				out.append(def)
				break
			s = s.get_base_script()
	return out


func count() -> int:
	return _by_id.size()


## Registro manual (útil para tests y contenido generado en tiempo de ejecución).
func register(def: GameDef) -> bool:
	if def.id == &"":
		push_error("DataRegistry: definición sin id (%s)." % def.resource_path)
		return false
	if _by_id.has(def.id) and _by_id[def.id] != def:
		push_error("DataRegistry: id duplicado '%s' en «%s» y «%s»." % [def.id, _by_id[def.id].resource_path, def.resource_path])
		return false
	_by_id[def.id] = def
	return true


func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for sub in dir.get_directories():
		_scan_dir(path.path_join(sub))
	for file in dir.get_files():
		# En exportaciones los recursos aparecen como "*.tres.remap".
		var clean := file.trim_suffix(".remap")
		if not (clean.ends_with(".tres") or clean.ends_with(".res")):
			continue
		var res := load(path.path_join(clean))
		if res is GameDef:
			register(res as GameDef)
