extends GutTest

const TMP_DIR := "user://test_saves"


class DummySaveable:
	extends Node
	var value := 0
	var pos := Vector3.ZERO

	func _init() -> void:
		add_to_group(&"saveable")

	func get_save_id() -> String:
		return "dummy"

	func save_state() -> Dictionary:
		return {"value": value, "pos": SaveManager.vec3_to_arr(pos)}

	func load_state(data: Dictionary) -> void:
		value = int(data.get("value", 0))
		pos = SaveManager.arr_to_vec3(data.get("pos"))


var _dummy: DummySaveable
var _prev_dir: String


func before_each() -> void:
	_prev_dir = SaveManager.save_dir
	SaveManager.save_dir = TMP_DIR
	_dummy = DummySaveable.new()
	add_child_autofree(_dummy)


func after_each() -> void:
	for f in DirAccess.get_files_at(TMP_DIR):
		DirAccess.remove_absolute(TMP_DIR.path_join(f))
	SaveManager.save_dir = _prev_dir


func test_roundtrip_restores_state() -> void:
	_dummy.value = 42
	_dummy.pos = Vector3(1.5, -2.0, 300.25)
	GameState.unlock(&"test_unlock")
	assert_eq(SaveManager.save_slot("slot_a"), OK)

	_dummy.value = 0
	_dummy.pos = Vector3.ZERO
	GameState.unlocks.clear()
	assert_eq(SaveManager.load_slot("slot_a"), OK)

	assert_eq(_dummy.value, 42)
	assert_almost_eq(_dummy.pos, Vector3(1.5, -2.0, 300.25), Vector3.ONE * 0.0001)
	assert_true(GameState.is_unlocked(&"test_unlock"), "GameState también se guarda")


func test_save_writes_versioned_metadata() -> void:
	SaveManager.save_slot("slot_meta")
	var p := SaveManager.read_slot("slot_meta")
	assert_eq(int(p.get("format_version")), SaveManager.FORMAT_VERSION)
	assert_true(p.has("saved_at"))
	assert_false(FileAccess.file_exists(TMP_DIR.path_join("slot_meta.json.tmp")), "sin temporales sueltos")


func test_corrupt_file_fails_without_changing_state() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var f := FileAccess.open(TMP_DIR.path_join("broken.json"), FileAccess.WRITE)
	f.store_string("{ esto no es json")
	f.close()
	_dummy.value = 7
	assert_ne(SaveManager.load_slot("broken"), OK)
	assert_eq(_dummy.value, 7)


func test_newer_format_is_rejected() -> void:
	DirAccess.make_dir_recursive_absolute(TMP_DIR)
	var f := FileAccess.open(TMP_DIR.path_join("future.json"), FileAccess.WRITE)
	f.store_string(JSON.stringify({"format_version": SaveManager.FORMAT_VERSION + 1, "data": {"dummy": {"value": 99}}}))
	f.close()
	assert_eq(SaveManager.load_slot("future"), ERR_FILE_UNRECOGNIZED)
	assert_ne(_dummy.value, 99)


func test_list_and_delete_slots() -> void:
	SaveManager.save_slot("one")
	SaveManager.save_slot("two")
	assert_eq(SaveManager.list_slots().size(), 2)
	assert_eq(SaveManager.delete_slot("one"), OK)
	assert_false(SaveManager.has_slot("one"))
