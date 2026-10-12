extends SceneTree
## Class settings link: parsing, which keys apply, that link settings are never saved, and that the main scene starts
## on the link's level with the level locked, the banner shown and no Teacher Mode button.

var _passed: int = 0
var _failed: int = 0

const FULL_LINK: String = "?level=3&locklevel=1&punnett=ratios&genotypes=hide&results=probabilities&seed=42&lockparents=1&nonew=1&maxgenes=2&lowspec=1&utm_source=x"
const SAVE_PATH: String = "user://teacher_mode_state.json"


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
	var tm: Node = get_root().get_node("/root/TeacherModeState")
	var hgs: Node = get_root().get_node("/root/HumanGeneticsState")

	var q: Dictionary = tm.parse_query("?Level=2&punnett=Ratios&name=a%20b&flag")
	_check(q.get("level") == "2" and q.get("punnett") == "ratios", "keys and values are lower-cased")
	_check(q.get("name") == "a b" and q.get("flag") == "", "values are decoded; a bare key has an empty value")
	_check(tm.parse_query("").is_empty() and tm.parse_query("?").is_empty(), "empty query gives nothing")

	_check(not tm.apply_link_settings(""), "no query: no link mode")
	_check(not tm.apply_link_settings("?level=99&punnett=sideways&seed=abc&maxgenes=9&foo=1"), "only bad values or unknown keys: no link mode")
	_check(not tm.is_active() and not tm.is_from_link(), "Teacher Mode stays off after a bad link")
	_check(tm.get_link_level() == 1 and not tm.is_level_locked(), "a bad link keeps level 1 unlocked")

	var existed: bool = FileAccess.file_exists(SAVE_PATH)
	var saved_before: String = FileAccess.get_file_as_string(SAVE_PATH) if existed else ""

	_check(tm.apply_link_settings(FULL_LINK), "full link applies")
	_check(tm.is_active() and tm.is_from_link(), "link switches Teacher Mode on")
	_check(tm.get_link_level() == 3 and tm.is_level_locked(), "level 3, locked")
	_check(tm.get_punnett_display_mode() == "ratios", "punnett=ratios")
	_check(not tm.should_show_genotype() and tm.should_show_phenotype(), "genotypes=hide keeps phenotypes")
	_check(tm.get_breeding_mode() == "preview", "results=probabilities")
	_check(tm.is_deterministic() and tm.get_random_seed() == 42, "seed=42")
	_check(tm.are_parents_locked(), "lockparents=1")
	_check(tm.is_generation_locked(), "nonew=1")
	_check(tm.get_max_genes_per_cross() == 2, "maxgenes=2")
	_check(tm.is_low_spec_mode(), "lowspec=1")
	var summary: String = tm.get_status_summary()
	_check(summary.begins_with("Class settings from your teacher's link") and summary.contains("seed 42"), "banner text names the settings")

	tm.set_lock_parents(false)
	var exists_now: bool = FileAccess.file_exists(SAVE_PATH)
	_check(exists_now == existed and (not exists_now or FileAccess.get_file_as_string(SAVE_PATH) == saved_before), "link settings are never saved")
	tm.set_lock_parents(true)

	var lab: Control = (load("res://scenes/main/GeneticsLab.tscn") as PackedScene).instantiate()
	get_root().add_child(lab)
	for i: int in range(20):
		await process_frame
	_check(hgs.current_level_id == 3, "the game starts on the link's level")
	_check(lab.level_dropdown.get_selected_id() == 3 and lab.level_dropdown.disabled, "level dropdown shows 3 and is locked")
	_check(lab.teacher_mode_banner.visible and lab.teacher_mode_status.text == summary, "banner shows the class settings")
	_check(not lab.teacher_mode_button.visible, "no Teacher Mode button with a link")
	_check(lab.footer_disclaimer.visible, "modelling disclaimer shown")

	print("Test Results: %d passed, %d failed" % [_passed, _failed])
	quit(1 if _failed > 0 else 0)
