extends SceneTree
## Smoke test: the main scene loads and runs frames, two humans are recombined and the result saved, and every
## level can be selected and recombined. run_all_tests.sh also fails a suite on any SCRIPT ERROR in its output.

var _passed: int = 0
var _failed: int = 0


func _init() -> void:
	_run()


func _check(cond: bool, label: String) -> void:
	if cond:
		_passed += 1
	else:
		_failed += 1
		print("FAIL: " + label)


func _run() -> void:
	await get_root().ready
	var state: Node = get_root().get_node("/root/HumanGeneticsState")
	var before: Array = []
	for h: Dictionary in state.get_all_humans():
		before.append(h.get("id", -1))
	var lab: Control = (load("res://scenes/main/GeneticsLab.tscn") as PackedScene).instantiate()
	get_root().add_child(lab)
	for i: int in range(30):
		await process_frame
	_check(lab.is_inside_tree() and lab.level_dropdown.item_count == 5, "scene runs with 5 levels")
	var a: int = state.generate_random_human()
	var b: int = state.generate_random_human()
	await process_frame
	_check(lab.library_panel.card_container.get_child_count() >= 2, "library shows the new humans")
	lab.breeding_area.set_parent_from_library(a, "A")
	lab.breeding_area.set_parent_from_library(b, "B")
	await process_frame
	_check(lab.breeding_area.parent_a_slot.has_human() and lab.breeding_area.parent_b_slot.has_human(), "both parents set")
	lab.breeding_area.recombine_button.pressed.emit()
	await process_frame
	var preview: Control = lab.breeding_area.offspring_preview
	_check(not preview.current_offspring_data.is_empty(), "recombination makes an offspring")
	preview.save_button.pressed.emit()
	preview.name_input.text = "Smoke Test"
	preview.confirm_button.pressed.emit()
	await process_frame
	var found: bool = false
	for h: Dictionary in state.get_all_humans():
		if h.get("name", "") == "Smoke Test":
			found = true
	_check(found, "saved offspring is in the library")
	# Every level loads and recombines without error
	for i: int in range(lab.level_dropdown.item_count):
		lab.level_dropdown.select(i)
		lab.level_dropdown.item_selected.emit(i)
		for f: int in range(5):
			await process_frame
		lab.breeding_area.set_parent_from_library(a, "A")
		lab.breeding_area.set_parent_from_library(b, "B")
		lab.breeding_area.recombine_button.pressed.emit()
		await process_frame
		_check(not preview.current_offspring_data.is_empty(), "level %d recombines" % (i + 1))
	# Manual popup text loads
	lab.manual_button.pressed.emit()
	await process_frame
	_check(lab.manual_text.text.length() > 100, "manual text loads")
	for h: Dictionary in state.get_all_humans().duplicate():
		if not (h.get("id", -1) in before):
			state.delete_human(h.get("id", -1))
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
