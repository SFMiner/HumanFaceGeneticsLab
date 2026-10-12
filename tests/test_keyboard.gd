extends SceneTree
## Keyboard use and the sims-site keyboard exit (SPEC section 6): Tab walks every visible control in order,
## Tab past the last and Shift+Tab before the first leave the game, Escape closes the innermost open thing
## (tutorial, popup, naming box) and only then leaves, A / B on a library card or Allele Bank chip fill a
## parent slot (the keyboard route for the drag), and every stop shows a focus outline.

const TUTORIAL_STATE: String = "user://tutorial_state.json"

var _passed: int = 0
var _failed: int = 0
var _lab: Control = null
var _state: Node = null
var _nav: Node = null
var _saved_tutorial_state: String = ""
var _had_tutorial_state: bool = false
var _library_before: Array = []


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
	_state = get_root().get_node("/root/HumanGeneticsState")
	# A saved "skip tutorial" choice would hide the tutorial box; set it aside for the test
	_had_tutorial_state = FileAccess.file_exists(TUTORIAL_STATE)
	if _had_tutorial_state:
		_saved_tutorial_state = FileAccess.get_file_as_string(TUTORIAL_STATE)
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_STATE))
	for h: Dictionary in _state.get_all_humans():
		_library_before.append(h.get("id", -1))
	_state.generate_random_human()
	_state.generate_random_human()
	_lab = (load("res://scenes/main/GeneticsLab.tscn") as PackedScene).instantiate()
	get_root().add_child(_lab)
	for i: int in range(8):
		await process_frame
	_nav = _lab.keyboard
	_check(_nav != null, "KeyboardNav is set up")
	if _nav == null:
		_finish()
		return

	var tutorial: Control = _lab.tutorial_panel
	_check(tutorial.visible, "the tutorial prompt is showing")

	# Tab from nothing focused: the tutorial box comes first
	await _key(KEY_TAB)
	var first: Control = get_root().gui_get_focus_owner()
	_check(first != null and tutorial.is_ancestor_of(first), "first Tab lands in the tutorial box")
	# Escape closes the tutorial first and does not leave
	var before: int = _nav.leave_count
	await _key(KEY_ESCAPE)
	_check(not tutorial.visible and _nav.leave_count == before, "Escape closes the tutorial without leaving")

	# Tab from nothing focused walks every control, then leaves past the last one
	get_root().gui_release_focus()
	var expected: Array[Control] = _nav.stops()
	_check(expected.size() > 10, "there are Tab stops (got %d)" % expected.size())
	_check(expected[0] == _lab.level_dropdown, "first stop is the level dropdown")
	_check(_lab.library_panel.generate_button in expected, "Generate is a stop")
	_check(_lab.manual_button in expected, "Manual is a stop")
	_check(not ("admin_button" in _lab) and _lab.get_node_or_null("AdminPinPopup") == null, "no Admin button or PIN box")
	var cards: Array[Control] = _cards()
	_check(cards.size() >= 2 and cards[0] in expected, "library cards are stops")
	_check(expected.find(cards[0]) < expected.find(_lab.library_panel.generate_button), "cards come before Generate")
	var chips: Array[Control] = _palette_chips()
	_check(chips.size() >= 6 and chips[0] in expected, "Allele Bank chips are stops")
	var stops: Array[Control] = []
	before = _nav.leave_count
	for i: int in range(expected.size() + 5):
		await _key(KEY_TAB)
		var f: Control = get_root().gui_get_focus_owner()
		if f == null:
			break
		stops.append(f)
	_check(stops == expected, "Tab visits exactly the stops, in order (%d of %d)" % [stops.size(), expected.size()])
	_check(_nav.leave_count == before + 1, "Tab past the last control leaves the game")
	_check(get_root().gui_get_focus_owner() == null, "focus is released after leaving")

	# Shift+Tab from nothing starts at the last control; before the first it leaves
	before = _nav.leave_count
	var back: Array[Control] = []
	for i: int in range(expected.size() + 5):
		await _key(KEY_TAB, true)
		var f: Control = get_root().gui_get_focus_owner()
		if f == null:
			break
		back.append(f)
	var reversed: Array[Control] = expected.duplicate()
	reversed.reverse()
	_check(back == reversed, "Shift+Tab walks the same controls backwards")
	_check(_nav.leave_count == before + 1, "Shift+Tab before the first control leaves the game")

	# Shift+Tab on the last control moves back instead of leaving (exact-match check)
	expected[-1].grab_focus()
	before = _nav.leave_count
	await _key(KEY_TAB, true)
	_check(_nav.leave_count == before and get_root().gui_get_focus_owner() == expected[-2], "Shift+Tab on the last stop moves back")

	# Escape from a control in the middle leaves
	_lab.library_panel.generate_button.grab_focus()
	before = _nav.leave_count
	await _key(KEY_ESCAPE)
	_check(_nav.leave_count == before + 1 and get_root().gui_get_focus_owner() == null, "Escape leaves the game")

	# Every stop shows a focus outline
	for c: Control in expected:
		var ok: bool = c.has_node("FocusRing")
		if not ok:
			var flat: StyleBoxFlat = c.get_theme_stylebox("focus") as StyleBoxFlat
			ok = flat != null and flat.border_color.r > 0.9 and flat.border_color.g > 0.8 and flat.border_color.b < 0.4
		_check(ok, "%s has a yellow focus outline" % c.name)

	# A / B on a library card fill the parent slots (the keyboard route for the drag)
	cards[0].grab_focus()
	await _key(KEY_A)
	_check(_lab.breeding_area.parent_a_slot.has_human(), "A on a card fills Parent A")
	cards[1].grab_focus()
	await _key(KEY_B)
	_check(_lab.breeding_area.parent_b_slot.has_human(), "B on a card fills Parent B")
	_check(not _lab.breeding_area.recombine_button.disabled, "Recombine is enabled once both parents are set")

	# A / B on an Allele Bank chip changes that gene on the parent
	var chip: Control = chips[2]
	chip.grab_focus()
	await _key(KEY_A)
	var geno: Dictionary = _lab.breeding_area.parent_a_slot.get_genotype()
	_check(geno.get(chip.get("gene_id"), []) == chip.get("alleles"), "A on a chip sets that gene on Parent A")
	var chip_b: Control = chips[1]
	chip_b.grab_focus()
	await _key(KEY_B)
	var geno_b: Dictionary = _lab.breeding_area.parent_b_slot.get_genotype()
	_check(geno_b.get(chip_b.get("gene_id"), []) == chip_b.get("alleles"), "B on a chip sets that gene on Parent B")

	# Enter on a card opens the big face; Escape closes it first, a second Escape leaves
	cards[0].grab_focus()
	await _key(KEY_ENTER)
	_check(_lab.face_preview_popup.visible, "Enter on a card opens the face preview")
	before = _nav.leave_count
	await _key(KEY_ESCAPE)
	_check(not _lab.face_preview_popup.visible and _nav.leave_count == before, "Escape closes the face preview without leaving")
	await _key(KEY_ESCAPE)
	_check(_nav.leave_count == before + 1, "a second Escape leaves")

	# The Manual popup closes with Escape and Tab inside it does not leave
	_lab.manual_button.pressed.emit()
	await process_frame
	_check(_lab.manual_popup.visible, "Manual opens")
	before = _nav.leave_count
	await _key(KEY_TAB)
	_check(_nav.leave_count == before, "Tab inside a popup does not leave the game")
	await _key(KEY_ESCAPE)
	_check(not _lab.manual_popup.visible and _nav.leave_count == before, "Escape closes the Manual without leaving")

	# Recombine, start naming the result, Escape cancels the naming, a second Escape leaves
	var preview: Control = _lab.breeding_area.offspring_preview
	_lab.breeding_area.recombine_button.pressed.emit()
	await process_frame
	_check(not preview.current_offspring_data.is_empty(), "Recombine makes an offspring")
	preview.save_button.pressed.emit()
	await process_frame
	_check(preview.name_input.visible, "Save opens the naming box")
	before = _nav.leave_count
	await _key(KEY_ESCAPE)
	_check(not preview.name_input.visible and _nav.leave_count == before, "Escape cancels naming without leaving")
	await _key(KEY_ESCAPE)
	_check(_nav.leave_count == before + 1, "a second Escape leaves")
	_finish()


func _cards() -> Array[Control]:
	var out: Array[Control] = []
	for c: Node in _lab.library_panel.card_container.get_children():
		if not c.is_queued_for_deletion():
			out.append(c as Control)
	return out


func _palette_chips() -> Array[Control]:
	var out: Array[Control] = []
	for n: Node in _lab.breeding_area.allele_palette.find_children("*", "PanelContainer", true, false):
		if "gene_id" in n and not n.is_queued_for_deletion():
			out.append(n as Control)
	return out


func _finish() -> void:
	# Leave the player's saved library and tutorial choice as they were
	for h: Dictionary in _state.get_all_humans().duplicate():
		if not (h.get("id", -1) in _library_before):
			_state.delete_human(h.get("id", -1))
	if FileAccess.file_exists(TUTORIAL_STATE):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(TUTORIAL_STATE))
	if _had_tutorial_state:
		var f: FileAccess = FileAccess.open(TUTORIAL_STATE, FileAccess.WRITE)
		f.store_string(_saved_tutorial_state)
		f.close()
	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)


func _key(code: Key, shift: bool = false) -> void:
	for pressed: bool in [true, false]:
		var e: InputEventKey = InputEventKey.new()
		e.keycode = code
		e.physical_keycode = code
		e.shift_pressed = shift
		e.pressed = pressed
		get_root().push_input(e)
	await process_frame
	await process_frame
