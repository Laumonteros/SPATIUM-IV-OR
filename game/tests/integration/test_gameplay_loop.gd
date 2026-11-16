extends GutTest
## Prueba de punta a punta del ciclo de la Etapa 1 sobre la escena real:
## región lunar + astronauta + recursos + escáner + guardado/carga.

const SESSION := "res://main/game_session.tscn"
const TMP_DIR := "user://test_saves_integration"

var _session: GameSession
var _prev_dir: String


func before_all() -> void:
	_prev_dir = SaveManager.save_dir
	SaveManager.save_dir = TMP_DIR
	_session = (load(SESSION) as PackedScene).instantiate() as GameSession
	add_child(_session)
	await wait_physics_frames(10)


func after_all() -> void:
	_session.queue_free()
	await wait_frames(10) # que el terreno anterior se libere por completo antes de la próxima sesión
	for f in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR.path_join(f))
	SaveManager.save_dir = _prev_dir
	get_tree().paused = false


func _field() -> ResourceField:
	return _session.region.get_node("ResourceField") as ResourceField


func _first_deposit(type: StringName) -> ResourceDeposit:
	for d in _field().get_deposits():
		if d.item_id == type and not d.is_depleted():
			return d
	return null


func test_world_is_populated() -> void:
	var counts := {}
	for d in _field().get_deposits():
		counts[d.item_id] = counts.get(d.item_id, 0) + 1
	for type: StringName in ResourceField.DEPOSITS:
		assert_gt(counts.get(type, 0), 0, "hay depósitos de %s" % type)
	assert_eq(DataRegistry.get_all_of(ItemDef).size() >= 4, true, "4 recursos definidos como datos")


func test_player_stands_on_terrain_with_lunar_gravity() -> void:
	var p := _session.player
	await wait_physics_frames(90)
	assert_true(p.is_on_floor(), "el astronauta queda apoyado en el terreno (pos=%s vel=%s)" % [p.global_position, p.velocity])
	assert_almost_eq(p.get_gravity().y, -1.62, 0.01, "gravedad lunar")


func test_resources_start_hidden_and_scanner_reveals_nearby() -> void:
	var dep := _first_deposit(&"regolith")
	assert_not_null(dep)
	assert_false(dep.discovered, "nada se revela antes de escanear")
	var p := _session.player
	p.global_position = dep.global_position + Vector3(20, 2, 0)
	await wait_physics_frames(30)
	watch_signals(EventBus)
	var sc := p.get_node("Scanner") as Scanner
	sc._emit_pulse()
	assert_signal_emitted(EventBus, "scan_completed")
	# cada depósito se marca cuando lo alcanza la onda del pulso
	await wait_seconds(sc.pulse_duration + 0.3)
	assert_true(dep.discovered, "el pulso descubre depósitos dentro del alcance")


func test_collect_adds_to_inventory_and_shrinks_deposit() -> void:
	var dep := _first_deposit(&"regolith")
	var p := _session.player
	p.global_position = dep.global_position + Vector3(1.4, 0.5, 0)
	p.velocity = Vector3.ZERO
	await wait_physics_frames(90)
	assert_true(p.is_on_floor(), "el astronauta llegó al suelo junto a la roca")
	var before := p.inventory.get_amount(&"regolith")
	var rem := dep.remaining
	dep._on_interacted(p)
	assert_eq(p.current_action, &"Collect", "se reproduce la animación de recolección")
	await wait_seconds(2.2)
	assert_eq(p.inventory.get_amount(&"regolith"), before + dep.yield_per_harvest, "el inventario se actualiza")
	assert_eq(dep.remaining, rem - 1, "el depósito se achica")
	assert_eq(p.current_action, &"", "la acción termina y devuelve el control")


func test_save_and_load_restore_inventory_position_and_deposits() -> void:
	var p := _session.player
	p.inventory.add(&"iron", 6)
	p.global_position = Vector3(10, 5, 10)
	await wait_physics_frames(5)
	var saved_pos := p.global_position
	var dep := _first_deposit(&"iron")
	dep.set_state(1, true)
	assert_eq(SaveManager.save_slot("it"), OK)

	p.inventory.remove(&"iron", p.inventory.get_amount(&"iron"))
	p.global_position = Vector3(-50, 5, -50)
	dep.set_state(dep.harvests, false)
	assert_eq(SaveManager.load_slot("it"), OK)

	assert_eq(p.inventory.get_amount(&"iron"), 6)
	assert_almost_eq(p.global_position, saved_pos, Vector3.ONE * 0.01)
	assert_eq(dep.remaining, 1)
	assert_true(dep.discovered)
