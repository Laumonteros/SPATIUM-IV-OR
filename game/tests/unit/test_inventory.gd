extends GutTest
## Inventario: cantidades, límite de masa del traje y persistencia.

var inv: Inventory


func before_each() -> void:
	inv = Inventory.new()
	inv.max_mass_kg = 20.0
	add_child_autofree(inv)


func test_add_and_remove() -> void:
	assert_eq(inv.add(&"regolith", 5), 5)
	assert_eq(inv.get_amount(&"regolith"), 5)
	assert_true(inv.remove(&"regolith", 3))
	assert_eq(inv.get_amount(&"regolith"), 2)
	assert_false(inv.remove(&"regolith", 9), "no se puede quitar más de lo que hay")


func test_mass_limit_uses_item_definitions() -> void:
	# hierro = 2 kg por unidad (definido en data/items/iron.tres)
	assert_eq(inv.add(&"iron", 15), 10, "solo entran 20 kg")
	assert_almost_eq(inv.get_total_mass(), 20.0, 0.001)
	watch_signals(inv)
	assert_eq(inv.add(&"regolith", 1), 0)
	assert_signal_emitted(inv, "rejected")


func test_save_roundtrip() -> void:
	inv.add(&"water_ice", 3)
	var data := inv.save_state()
	var other := Inventory.new()
	add_child_autofree(other)
	other.load_state(data)
	assert_eq(other.get_amount(&"water_ice"), 3)


func test_every_item_has_science_source_and_texts() -> void:
	for def: GameDef in DataRegistry.get_all_of(ItemDef):
		var item := def as ItemDef
		assert_not_null(item.science, "%s tiene respaldo científico" % item.id)
		assert_ne(tr(item.name_key), item.name_key, "%s tiene nombre traducido" % item.id)
		assert_ne(tr(item.description_key), item.description_key, "%s tiene descripción" % item.id)
		assert_not_null(item.world_scene, "%s tiene modelo 3D" % item.id)
