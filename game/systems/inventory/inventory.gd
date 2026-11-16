class_name Inventory
extends Node
## Inventario de recursos (cantidades por id de `ItemDef`).
##
## Límite por masa total transportable en el traje. Guarda su estado vía Saveable.

signal changed(item_id: StringName, new_amount: int, delta: int)
signal rejected(item_id: StringName, reason: StringName)

@export var save_id: String = "player_inventory"
## Masa máxima transportable (kg). En la Luna el peso es 1/6 del terrestre, pero la
## inercia de la masa sigue siendo la misma: por eso el límite es de masa, no de peso.
@export var max_mass_kg: float = 120.0

var _items: Dictionary[StringName, int] = {}


func _ready() -> void:
	add_to_group(&"saveable")


func get_amount(id: StringName) -> int:
	return _items.get(id, 0)


func get_all() -> Dictionary[StringName, int]:
	return _items.duplicate()


func get_total_mass() -> float:
	var total := 0.0
	for id: StringName in _items:
		total += _unit_mass(id) * _items[id]
	return total


## Agrega hasta `amount` unidades; devuelve cuántas entraron.
func add(id: StringName, amount: int) -> int:
	if amount <= 0:
		return 0
	var unit := _unit_mass(id)
	var fits := amount
	if unit > 0.0:
		fits = mini(amount, int(floor((max_mass_kg - get_total_mass()) / unit + 0.0001)))
	if fits <= 0:
		rejected.emit(id, &"full")
		return 0
	_items[id] = get_amount(id) + fits
	changed.emit(id, _items[id], fits)
	return fits


## Quita `amount` unidades si hay suficientes; devuelve true si se pudo.
func remove(id: StringName, amount: int) -> bool:
	if amount <= 0 or get_amount(id) < amount:
		return false
	_items[id] -= amount
	if _items[id] == 0:
		_items.erase(id)
	changed.emit(id, get_amount(id), -amount)
	return true


func has(id: StringName, amount: int) -> bool:
	return get_amount(id) >= amount


func _unit_mass(id: StringName) -> float:
	var def := DataRegistry.get_def(id) as ItemDef
	return def.unit_mass_kg if def else 0.0


# --- Protocolo Saveable -----------------------------------------------------

func get_save_id() -> String:
	return save_id


func save_state() -> Dictionary:
	var out := {}
	for id: StringName in _items:
		out[String(id)] = _items[id]
	return {"items": out}


func load_state(data: Dictionary) -> void:
	for id: StringName in _items.keys():
		changed.emit(id, 0, -_items[id])
	_items.clear()
	var items: Dictionary = data.get("items", {})
	for k: String in items:
		_items[StringName(k)] = int(items[k])
		changed.emit(StringName(k), _items[StringName(k)], _items[StringName(k)])
