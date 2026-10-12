# TeacherModeState.gd
# Teacher Mode controller for the Human Face Genetics Simulator
# Enforces pedagogical constraints, deterministic demonstrations, and ethical safeguards
# Educational purpose: Prevent classroom failure modes (cognitive overload, misuse, click-until-correct)

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal teacher_mode_toggled(active: bool)
signal constraints_changed()
signal gene_visibility_changed()
signal punnett_display_changed()

# ============================================================================
# STATE VARIABLES
# ============================================================================

## Core state
var _active: bool = false
var _disclaimer_shown_this_session: bool = false

## Gene constraints
var _active_genes: Array = ["TYR", "OCA2", "HERC2"]
var _lock_genes_to_level: bool = true

## Breeding constraints
var _max_genes_per_cross: int = 2
var _lock_parents: bool = false
var _allow_self_breeding: bool = true
var _breeding_mode: String = "random"  # "random", "fixed", "preview"
var _fixed_cell_index: int = 0

## Visibility constraints
var _punnett_display_mode: String = "full"  # "full", "ratios", "single_gene", "hidden"
var _trait_visibility: String = "both"  # "phenotype", "genotype", "both"
var _hide_alleles: bool = false
var _hide_dominance_labels: bool = false
var _hide_epistasis_explanations: bool = false
var _hide_numerical_scores: bool = false

## Randomness
var _deterministic_mode: bool = false
var _random_seed: int = 42
var _seeded_rng: RandomNumberGenerator = RandomNumberGenerator.new()

## Ethics & language
var _enforce_neutral_language: bool = true
var _show_modeling_disclaimer: bool = true
var _naming_mode: String = "random"  # "generic", "random", "custom"
var _custom_naming_prefix: String = "Human"

## Generation control
var _allow_generation: bool = true

## Low-spec mode
var _low_spec_mode: bool = false

## Class settings link (web): settings come from the page address, apply to this visit only and are never saved
var _from_link: bool = false
var _link_level: int = 1
var _lock_level: bool = false
var _link_notes: Array[String] = []

## Link keys and the values each accepts. Keep in step with README "Class settings link" and the site's form.
const LINK_KEYS: Dictionary = {
	"level": "1-5",
	"locklevel": "1",
	"punnett": "full | ratios | single | hidden",
	"genotypes": "show | hide",
	"results": "offspring | probabilities",
	"seed": "1-999999999",
	"lockparents": "1",
	"nonew": "1",
	"maxgenes": "1-4",
	"lowspec": "1",
}

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_load_defaults()
	_seeded_rng.seed = _random_seed
	if OS.has_feature("web"):
		apply_link_settings(_read_page_query())


## The query string of the game's own address, or else of the play page around it (same origin on the sims site).
func _read_page_query() -> String:
	var js: String = "(function(){var q=window.location.search;if(!q){try{q=window.parent.location.search;}catch(e){q='';}}return q||'';})()"
	var result: Variant = JavaScriptBridge.eval(js, true)
	return result if result is String else ""


## Load defaults from JSON config
func _load_defaults() -> void:
	var file := FileAccess.open("res://data/teacher_mode_defaults.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			_active = data.get("active", false)
			_active_genes = data.get("active_genes", ["TYR", "OCA2", "HERC2"])
			_max_genes_per_cross = data.get("max_genes_per_cross", 2)
			_punnett_display_mode = data.get("punnett_display_mode", "full")
			_trait_visibility = data.get("trait_visibility", "both")
			_breeding_mode = data.get("breeding_mode", "random")
			_lock_parents = data.get("lock_parents", false)
			_allow_generation = data.get("allow_generation", true)
			_random_seed = data.get("deterministic_seed", 42) if data.get("deterministic_seed") != null else 42
			_enforce_neutral_language = data.get("language_enforcement", true)
			_show_modeling_disclaimer = data.get("show_ethical_disclaimer", true)
			_low_spec_mode = data.get("low_spec_mode", false)
			_naming_mode = data.get("naming_mode", "random")
			_custom_naming_prefix = data.get("custom_naming_prefix", "Human")


# ============================================================================
# ACTIVATION
# ============================================================================

## Check if Teacher Mode is active
func is_active() -> bool:
	return _active


## Set Teacher Mode active state
func set_active(active: bool) -> void:
	var was_active := _active
	_active = active
	
	if active and not was_active:
		# Show disclaimer on first activation per session
		if not _disclaimer_shown_this_session and _show_modeling_disclaimer:
			_disclaimer_shown_this_session = true
		
		# Apply deterministic seed if enabled
		if _deterministic_mode:
			_seeded_rng.seed = _random_seed
	
	teacher_mode_toggled.emit(active)
	_save_state()


## Toggle Teacher Mode
func toggle() -> bool:
	set_active(not _active)
	return _active


# ============================================================================
# GENE CONSTRAINTS
# ============================================================================

## Get currently active genes (respects lock_to_level setting)
func get_active_genes() -> Array:
	if not _active:
		return HumanGeneticsState.get_active_genes()
	
	if _lock_genes_to_level:
		return HumanGeneticsState.get_active_genes()
	
	return _active_genes


## Set active genes manually
func set_active_genes(genes: Array) -> void:
	_active_genes = genes
	gene_visibility_changed.emit()
	constraints_changed.emit()
	_save_state()


## Check if a gene should be visible
func is_gene_visible(gene_id: String) -> bool:
	if not _active:
		return gene_id in HumanGeneticsState.get_active_genes()
	
	return gene_id in get_active_genes()


## Set whether to lock genes to current level
func set_lock_genes_to_level(lock: bool) -> void:
	_lock_genes_to_level = lock
	gene_visibility_changed.emit()
	constraints_changed.emit()
	_save_state()


## Check if genes are locked to level
func is_genes_locked_to_level() -> bool:
	return _lock_genes_to_level


# ============================================================================
# BREEDING CONSTRAINTS
# ============================================================================

## Check if breeding is allowed between two humans
func can_breed(parent_a_id: int, parent_b_id: int) -> bool:
	if not _active:
		return true
	
	# Check self-breeding
	if parent_a_id == parent_b_id and not _allow_self_breeding:
		return false
	
	return true


## Get max genes allowed per cross
func get_max_genes_per_cross() -> int:
	if not _active:
		return HumanGeneticsState.get_max_punnett_genes()
	return _max_genes_per_cross


## Set max genes per cross
func set_max_genes_per_cross(max_genes: int) -> void:
	_max_genes_per_cross = clampi(max_genes, 1, 4)
	constraints_changed.emit()
	_save_state()


## Check if parents are locked after selection
func are_parents_locked() -> bool:
	return _active and _lock_parents


## Set parent lock state
func set_lock_parents(lock: bool) -> void:
	_lock_parents = lock
	constraints_changed.emit()
	_save_state()


## Get current breeding mode
func get_breeding_mode() -> String:
	if not _active:
		return "random"
	return _breeding_mode


## Set breeding mode
func set_breeding_mode(mode: String) -> void:
	if mode in ["random", "fixed", "preview"]:
		_breeding_mode = mode
		constraints_changed.emit()
		_save_state()


## Get fixed cell index (for fixed breeding mode)
func get_fixed_cell_index() -> int:
	return _fixed_cell_index


## Set fixed cell index
func set_fixed_cell_index(index: int) -> void:
	_fixed_cell_index = max(0, index)
	_save_state()


## Check if self-breeding is allowed
func is_self_breeding_allowed() -> bool:
	if not _active:
		return true
	return _allow_self_breeding


## Set self-breeding allowance
func set_allow_self_breeding(allow: bool) -> void:
	_allow_self_breeding = allow
	constraints_changed.emit()
	_save_state()


# ============================================================================
# VISIBILITY CONSTRAINTS
# ============================================================================

## Check if Punnett should collapse based on gene count
func should_collapse_punnett(gene_count: int) -> bool:
	if not _active:
		return gene_count > 2
	return gene_count > _max_genes_per_cross


## Get Punnett display mode
func get_punnett_display_mode() -> String:
	if not _active:
		return "full"
	return _punnett_display_mode


## Set Punnett display mode
func set_punnett_display_mode(mode: String) -> void:
	if mode in ["full", "ratios", "single_gene", "hidden"]:
		_punnett_display_mode = mode
		punnett_display_changed.emit()
		constraints_changed.emit()
		_save_state()


## Get trait visibility mode
func get_trait_visibility() -> String:
	if not _active:
		return "both"
	return _trait_visibility


## Set trait visibility mode
func set_trait_visibility(mode: String) -> void:
	if mode in ["phenotype", "genotype", "both"]:
		_trait_visibility = mode
		constraints_changed.emit()
		_save_state()


## Check if phenotype should be visible
func should_show_phenotype() -> bool:
	if not _active:
		return true
	return _trait_visibility in ["phenotype", "both"]


## Check if genotype should be visible
func should_show_genotype() -> bool:
	if not _active:
		return true
	return _trait_visibility in ["genotype", "both"]


## Get information masking settings
func should_hide_alleles() -> bool:
	return _active and _hide_alleles


func should_hide_dominance_labels() -> bool:
	return _active and _hide_dominance_labels


func should_hide_epistasis_explanations() -> bool:
	return _active and _hide_epistasis_explanations


func should_hide_numerical_scores() -> bool:
	return _active and _hide_numerical_scores


## Set information masking
func set_hide_alleles(hide: bool) -> void:
	_hide_alleles = hide
	constraints_changed.emit()
	_save_state()


func set_hide_dominance_labels(hide: bool) -> void:
	_hide_dominance_labels = hide
	constraints_changed.emit()
	_save_state()


func set_hide_epistasis_explanations(hide: bool) -> void:
	_hide_epistasis_explanations = hide
	constraints_changed.emit()
	_save_state()


func set_hide_numerical_scores(hide: bool) -> void:
	_hide_numerical_scores = hide
	constraints_changed.emit()
	_save_state()


# ============================================================================
# RANDOMNESS CONTROLS
# ============================================================================

## Check if deterministic mode is active
func is_deterministic() -> bool:
	return _active and _deterministic_mode


## Set deterministic mode
func set_deterministic(deterministic: bool) -> void:
	_deterministic_mode = deterministic
	if deterministic:
		_seeded_rng.seed = _random_seed
	constraints_changed.emit()
	_save_state()


## Get current random seed
func get_random_seed() -> int:
	return _random_seed


## Set random seed
func set_random_seed(seed_value: int) -> void:
	_random_seed = seed_value
	_seeded_rng.seed = seed_value
	_save_state()


## Generate a new random seed
func generate_new_seed() -> int:
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	_random_seed = rng.randi()
	_seeded_rng.seed = _random_seed
	_save_state()
	return _random_seed


## Get a seeded random integer (for deterministic breeding)
func get_seeded_random_int(min_val: int, max_val: int) -> int:
	return _seeded_rng.randi_range(min_val, max_val)


## Get a seeded random float (for deterministic allele generation)
func get_seeded_random_float() -> float:
	return _seeded_rng.randf()


# ============================================================================
# GENERATION CONTROLS
# ============================================================================

## Check if random human generation is allowed
func is_generation_allowed() -> bool:
	if not _active:
		return true
	return _allow_generation


## Set generation allowance
func set_allow_generation(allow: bool) -> void:
	_allow_generation = allow
	constraints_changed.emit()
	_save_state()


## Check if generation UI is locked
func is_generation_locked() -> bool:
	return _active and not _allow_generation


# ============================================================================
# ETHICS & LANGUAGE
# ============================================================================

## Check if neutral language should be enforced
func should_enforce_neutral_language() -> bool:
	return _active and _enforce_neutral_language


## Set neutral language enforcement
func set_enforce_neutral_language(enforce: bool) -> void:
	_enforce_neutral_language = enforce
	constraints_changed.emit()
	_save_state()


## Get the ethical disclaimer text
func get_ethical_disclaimer() -> String:
	return "This simulator models simplified genetics for learning purposes.\nIt does not predict real people or outcomes."


## Check if modeling disclaimer should be shown
func should_show_modeling_disclaimer() -> bool:
	return _active and _show_modeling_disclaimer


## Set modeling disclaimer visibility
func set_show_modeling_disclaimer(show: bool) -> void:
	_show_modeling_disclaimer = show
	_save_state()


## Get the footer disclaimer text
func get_footer_disclaimer() -> String:
	return "Traits shown are not ranked and have no inherent value."


## Apply neutral language to text
func apply_neutral_language(text: String) -> String:
	if not should_enforce_neutral_language():
		return text
	
	# Replace value-laden terms with neutral alternatives
	var replacements: Dictionary = {
		"better": "more likely",
		"worse": "less likely",
		"best": "most likely",
		"worst": "least likely",
		"ideal": "expected",
		"optimal": "common",
		"normal": "typical",
		"abnormal": "less common",
		"defect": "variation",
		"superior": "more frequent",
		"inferior": "less frequent"
	}
	
	var result := text
	for original in replacements.keys():
		result = result.replacen(original, replacements[original])
	
	return result


# ============================================================================
# NAMING CONTROLS
# ============================================================================

## Get naming mode
func get_naming_mode() -> String:
	if not _active:
		return "random"
	return _naming_mode


## Set naming mode
func set_naming_mode(mode: String) -> void:
	if mode in ["generic", "random", "custom"]:
		_naming_mode = mode
		_save_state()


## Get custom naming prefix
func get_custom_naming_prefix() -> String:
	return _custom_naming_prefix


## Set custom naming prefix
func set_custom_naming_prefix(prefix: String) -> void:
	_custom_naming_prefix = prefix
	_save_state()


## Generate a name based on current mode
func generate_name(human_id: int) -> String:
	match get_naming_mode():
		"generic":
			return "Human %03d" % human_id
		"custom":
			return "%s %03d" % [_custom_naming_prefix, human_id]
		_:
			return HumanGeneticsState.generate_random_name()


# ============================================================================
# LOW-SPEC MODE
# ============================================================================

## Check if low-spec mode is enabled
func is_low_spec_mode() -> bool:
	return _low_spec_mode


## Set low-spec mode
func set_low_spec_mode(enabled: bool) -> void:
	_low_spec_mode = enabled
	constraints_changed.emit()
	_save_state()


# ============================================================================
# SESSION MANAGEMENT
# ============================================================================

## Reset to defaults from JSON config
func reset_to_defaults() -> void:
	_load_defaults()
	_seeded_rng.seed = _random_seed
	constraints_changed.emit()
	gene_visibility_changed.emit()
	punnett_display_changed.emit()


## Reset session (clear library but keep settings)
func session_reset() -> void:
	HumanGeneticsState.clear_library()
	_disclaimer_shown_this_session = false
	if _deterministic_mode:
		_seeded_rng.seed = _random_seed


## Export session snapshot
func export_session_snapshot() -> Dictionary:
	return {
		"timestamp": Time.get_unix_time_from_system(),
		"teacher_mode_active": _active,
		"active_genes": get_active_genes(),
		"max_genes_per_cross": _max_genes_per_cross,
		"breeding_mode": _breeding_mode,
		"deterministic": _deterministic_mode,
		"random_seed": _random_seed if _deterministic_mode else null,
		"humans": HumanGeneticsState.get_all_humans(),
		"current_level": HumanGeneticsState.current_level_id
	}


# ============================================================================
# CLASS SETTINGS LINK
# ============================================================================

## Split "?a=1&b=two" into {"a": "1", "b": "two"}; keys lower-cased, values decoded and trimmed.
static func parse_query(query: String) -> Dictionary:
	var out: Dictionary = {}
	for part: String in query.trim_prefix("?").split("&", false):
		var eq: int = part.find("=")
		var key: String = (part if eq < 0 else part.substr(0, eq)).uri_decode().strip_edges().to_lower()
		var value: String = ("" if eq < 0 else part.substr(eq + 1)).uri_decode().strip_edges().to_lower()
		if not key.is_empty():
			out[key] = value
	return out


## Apply the recognised keys of a settings link. Unknown keys and bad values are ignored, so a mistyped link
## still opens the game. Returns true when at least one setting was applied (Teacher Mode is then on).
func apply_link_settings(query: String) -> bool:
	var params: Dictionary = parse_query(query)
	var notes: Array[String] = []
	var level: int = _int_in(params.get("level", ""), 1, HumanGeneticsState.get_all_levels().size())
	if level > 0:
		_link_level = level
		notes.append("Level %d" % level)
	if params.get("locklevel", "") == "1":
		_lock_level = true
		notes.append("level locked")
	match params.get("punnett", ""):
		"full":
			_punnett_display_mode = "full"
			notes.append("full Punnett square")
		"ratios":
			_punnett_display_mode = "ratios"
			notes.append("Punnett square shows ratios only")
		"single":
			_punnett_display_mode = "single_gene"
			notes.append("Punnett square shows one gene")
		"hidden":
			_punnett_display_mode = "hidden"
			notes.append("Punnett square hidden")
	if params.get("genotypes", "") == "hide":
		_trait_visibility = "phenotype"
		notes.append("genotypes hidden")
	elif params.get("genotypes", "") == "show":
		_trait_visibility = "both"
		notes.append("genotypes shown")
	if params.get("results", "") == "probabilities":
		_breeding_mode = "preview"
		notes.append("probabilities only, no offspring")
	elif params.get("results", "") == "offspring":
		_breeding_mode = "random"
		notes.append("offspring shown")
	var seed_value: int = _int_in(params.get("seed", ""), 1, 999999999)
	if seed_value > 0:
		_deterministic_mode = true
		_random_seed = seed_value
		_seeded_rng.seed = seed_value
		notes.append("same results for everyone (seed %d)" % seed_value)
	if params.get("lockparents", "") == "1":
		_lock_parents = true
		notes.append("parents lock after recombining")
	if params.get("nonew", "") == "1":
		_allow_generation = false
		notes.append("no new random humans")
	var max_genes: int = _int_in(params.get("maxgenes", ""), 1, 4)
	if max_genes > 0:
		_max_genes_per_cross = max_genes
		notes.append("up to %d genes per cross" % max_genes)
	if params.get("lowspec", "") == "1":
		_low_spec_mode = true
		notes.append("simpler drawing")
	if notes.is_empty():
		return false
	_from_link = true
	_link_notes = notes
	_active = true
	teacher_mode_toggled.emit(true)
	constraints_changed.emit()
	return true


## A whole number in [lo, hi], or 0 when the text is not one.
static func _int_in(text: String, lo: int, hi: int) -> int:
	if not text.is_valid_int():
		return 0
	var n: int = text.to_int()
	return n if n >= lo and n <= hi else 0


func is_from_link() -> bool:
	return _from_link


## The level a settings link starts on (1 without a link).
func get_link_level() -> int:
	return _link_level


func is_level_locked() -> bool:
	return _from_link and _lock_level


# ============================================================================
# STATUS SUMMARY
# ============================================================================

## Get a compact status summary string
func get_status_summary() -> String:
	if not _active:
		return ""
	if _from_link:
		return "Class settings from your teacher's link: " + ", ".join(_link_notes)
	
	var parts: Array = []
	parts.append("Active genes: %s" % ", ".join(get_active_genes()))
	parts.append("Max genes: %d" % _max_genes_per_cross)
	
	if _deterministic_mode:
		parts.append("Randomness: Seeded (%d)" % _random_seed)
	else:
		parts.append("Randomness: True random")
	
	return " • ".join(parts)


# ============================================================================
# PERSISTENCE
# ============================================================================

## Save current state to user data
func _save_state() -> void:
	if _from_link:
		return
	var data: Dictionary = {
		"active": _active,
		"active_genes": _active_genes,
		"lock_genes_to_level": _lock_genes_to_level,
		"max_genes_per_cross": _max_genes_per_cross,
		"lock_parents": _lock_parents,
		"allow_self_breeding": _allow_self_breeding,
		"breeding_mode": _breeding_mode,
		"fixed_cell_index": _fixed_cell_index,
		"punnett_display_mode": _punnett_display_mode,
		"trait_visibility": _trait_visibility,
		"hide_alleles": _hide_alleles,
		"hide_dominance_labels": _hide_dominance_labels,
		"hide_epistasis_explanations": _hide_epistasis_explanations,
		"hide_numerical_scores": _hide_numerical_scores,
		"deterministic_mode": _deterministic_mode,
		"random_seed": _random_seed,
		"enforce_neutral_language": _enforce_neutral_language,
		"show_modeling_disclaimer": _show_modeling_disclaimer,
		"naming_mode": _naming_mode,
		"custom_naming_prefix": _custom_naming_prefix,
		"allow_generation": _allow_generation,
		"low_spec_mode": _low_spec_mode
	}
	
	var file := FileAccess.open("user://teacher_mode_state.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()


## Load state from user data
func load_state() -> void:
	if not FileAccess.file_exists("user://teacher_mode_state.json"):
		return
	
	var file := FileAccess.open("user://teacher_mode_state.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			_active = data.get("active", false)
			_active_genes = data.get("active_genes", ["TYR", "OCA2", "HERC2"])
			_lock_genes_to_level = data.get("lock_genes_to_level", true)
			_max_genes_per_cross = data.get("max_genes_per_cross", 2)
			_lock_parents = data.get("lock_parents", false)
			_allow_self_breeding = data.get("allow_self_breeding", true)
			_breeding_mode = data.get("breeding_mode", "random")
			_fixed_cell_index = data.get("fixed_cell_index", 0)
			_punnett_display_mode = data.get("punnett_display_mode", "full")
			_trait_visibility = data.get("trait_visibility", "both")
			_hide_alleles = data.get("hide_alleles", false)
			_hide_dominance_labels = data.get("hide_dominance_labels", false)
			_hide_epistasis_explanations = data.get("hide_epistasis_explanations", false)
			_hide_numerical_scores = data.get("hide_numerical_scores", false)
			_deterministic_mode = data.get("deterministic_mode", false)
			_random_seed = data.get("random_seed", 42)
			_enforce_neutral_language = data.get("enforce_neutral_language", true)
			_show_modeling_disclaimer = data.get("show_modeling_disclaimer", true)
			_naming_mode = data.get("naming_mode", "random")
			_custom_naming_prefix = data.get("custom_naming_prefix", "Human")
			_allow_generation = data.get("allow_generation", true)
			_low_spec_mode = data.get("low_spec_mode", false)
			
			if _deterministic_mode:
				_seeded_rng.seed = _random_seed
