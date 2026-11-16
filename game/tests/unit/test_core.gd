extends GutTest
## DataRegistry, ScienceSource y StateMachine.


func after_all() -> void:
	DataRegistry.rebuild() # quitar los ítems de prueba del registro global


func _make_item(id: StringName) -> ItemDef:
	var d := ItemDef.new()
	d.id = id
	return d


func test_registry_registers_and_filters_by_type() -> void:
	var item := _make_item(&"test_item_x")
	assert_true(DataRegistry.register(item))
	assert_eq(DataRegistry.get_def(&"test_item_x"), item)
	assert_has(DataRegistry.get_all_of(ItemDef), item)
	assert_has(DataRegistry.get_all_of(GameDef), item, "las subclases cuentan como GameDef")


func test_registry_rejects_duplicates_and_empty_ids() -> void:
	DataRegistry.register(_make_item(&"test_dup"))
	assert_false(DataRegistry.register(_make_item(&"test_dup")))
	assert_false(DataRegistry.register(_make_item(&"")))
	assert_push_error_count(2)


func test_science_source_real_vs_gameplay() -> void:
	var s := ScienceSource.new()
	assert_false(s.is_real(), "por defecto un valor es de juego, nunca real")
	s.kind = ScienceSource.Kind.REAL_DATA
	assert_true(s.is_real())


class StateA:
	extends State
	var entered := 0
	func enter(_from: StringName, _msg: Dictionary) -> void:
		entered += 1


class StateB:
	extends State
	var got_msg := {}
	func enter(_from: StringName, msg: Dictionary) -> void:
		got_msg = msg


func test_state_machine_transitions() -> void:
	var sm := StateMachine.new()
	var a := StateA.new()
	a.name = "A"
	var b := StateB.new()
	b.name = "B"
	sm.add_child(a)
	sm.add_child(b)
	sm.initial_state = a
	watch_signals(sm)
	add_child_autofree(sm)
	assert_eq(sm.current, a)
	assert_eq(a.entered, 1)
	sm.transition_to(&"B", {"speed": 3})
	assert_eq(sm.current, b)
	assert_eq(b.got_msg.get("speed"), 3)
	assert_signal_emitted_with_parameters(sm, "state_changed", [&"A", &"B"])
