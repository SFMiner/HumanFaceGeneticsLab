extends PanelContainer
class_name TeacherModePanel
## Modal panel for Teacher Mode controls with tabbed interface
## Tabs: Genes, Breeding, Visibility, Randomness, Ethics

signal panel_closed
signal session_reset_requested
signal snapshot_exported(data: Dictionary)

@onready var tab_container: TabContainer = $MarginContainer/VBoxContainer/TabContainer
@onready var close_button: Button = $MarginContainer/VBoxContainer/HeaderHBox/CloseButton
@onready var active_toggle: CheckButton = $MarginContainer/VBoxContainer/HeaderHBox/ActiveToggle
@onready var apply_button: Button = $MarginContainer/VBoxContainer/FooterHBox/ApplyButton
@onready var reset_defaults_button: Button = $MarginContainer/VBoxContainer/FooterHBox/ResetDefaultsButton
@onready var export_button: Button = $MarginContainer/VBoxContainer/FooterHBox/ExportButton
@onready var session_reset_button: Button = $MarginContainer/VBoxContainer/FooterHBox/SessionResetButton

# Genes tab
@onready var genes_container: VBoxContainer = $MarginContainer/VBoxContainer/TabContainer/Genes/VBox/ScrollContainer/GenesContainer
@onready var lock_to_level_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Genes/VBox/LockToLevelCheck

# Breeding tab
@onready var max_genes_spin: SpinBox = $MarginContainer/VBoxContainer/TabContainer/Breeding/VBox/MaxGenesHBox/MaxGenesSpin
@onready var lock_parents_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Breeding/VBox/LockParentsCheck
@onready var allow_self_breeding_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Breeding/VBox/AllowSelfBreedingCheck
@onready var breeding_mode_option: OptionButton = $MarginContainer/VBoxContainer/TabContainer/Breeding/VBox/BreedingModeHBox/BreedingModeOption

# Visibility tab
@onready var trait_visibility_option: OptionButton = $MarginContainer/VBoxContainer/TabContainer/Visibility/VBox/TraitVisibilityHBox/TraitVisibilityOption
@onready var punnett_mode_option: OptionButton = $MarginContainer/VBoxContainer/TabContainer/Visibility/VBox/PunnettModeHBox/PunnettModeOption
@onready var hide_alleles_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Visibility/VBox/HideAllelesCheck
@onready var hide_dominance_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Visibility/VBox/HideDominanceCheck
@onready var low_spec_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Visibility/VBox/LowSpecCheck

# Randomness tab
@onready var deterministic_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Randomness/VBox/DeterministicCheck
@onready var seed_spin: SpinBox = $MarginContainer/VBoxContainer/TabContainer/Randomness/VBox/SeedHBox/SeedSpin
@onready var new_seed_button: Button = $MarginContainer/VBoxContainer/TabContainer/Randomness/VBox/SeedHBox/NewSeedButton
@onready var disable_generation_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Randomness/VBox/DisableGenerationCheck

# Ethics tab
@onready var neutral_language_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Ethics/VBox/NeutralLanguageCheck
@onready var show_disclaimer_check: CheckButton = $MarginContainer/VBoxContainer/TabContainer/Ethics/VBox/ShowDisclaimerCheck
@onready var naming_mode_option: OptionButton = $MarginContainer/VBoxContainer/TabContainer/Ethics/VBox/NamingModeHBox/NamingModeOption
@onready var custom_prefix_input: LineEdit = $MarginContainer/VBoxContainer/TabContainer/Ethics/VBox/CustomPrefixHBox/CustomPrefixInput
@onready var custom_prefix_hbox: HBoxContainer = $MarginContainer/VBoxContainer/TabContainer/Ethics/VBox/CustomPrefixHBox

var _gene_checkboxes: Dictionary = {}  # gene_id -> CheckButton


func _ready() -> void:
	close_button.pressed.connect(_on_close_pressed)
	active_toggle.toggled.connect(_on_active_toggled)
	apply_button.pressed.connect(_on_apply_pressed)
	reset_defaults_button.pressed.connect(_on_reset_defaults_pressed)
	export_button.pressed.connect(_on_export_pressed)
	session_reset_button.pressed.connect(_on_session_reset_pressed)
	
	# Randomness tab
	deterministic_check.toggled.connect(_on_deterministic_toggled)
	new_seed_button.pressed.connect(_on_new_seed_pressed)
	
	# Ethics tab
	naming_mode_option.item_selected.connect(_on_naming_mode_changed)
	
	# Build gene checkboxes
	_build_gene_checkboxes()
	
	# Populate option buttons
	_populate_options()
	
	# Load current state
	_load_current_state()
	
	# Start hidden
	visible = false


func _build_gene_checkboxes() -> void:
	## Create checkboxes for each gene in the library
	var gene_library: Dictionary = HumanGeneticsState.GENE_LIBRARY
	
	for gene_id in gene_library:
		var gene_info: Dictionary = gene_library[gene_id]
		
		var hbox := HBoxContainer.new()
		
		var checkbox := CheckButton.new()
		checkbox.text = gene_id
		checkbox.tooltip_text = gene_info.get("full_name", gene_id) + "\n" + gene_info.get("description", "")
		checkbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(checkbox)
		
		var affects_label := Label.new()
		var affects: Array = gene_info.get("affects", [])
		affects_label.text = "→ " + ", ".join(affects)
		affects_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		affects_label.add_theme_font_size_override("font_size", 11)
		hbox.add_child(affects_label)
		
		genes_container.add_child(hbox)
		_gene_checkboxes[gene_id] = checkbox


func _populate_options() -> void:
	## Setup option button items
	
	# Breeding mode
	breeding_mode_option.clear()
	breeding_mode_option.add_item("Random", 0)
	breeding_mode_option.add_item("Teacher-Selected Cell", 1)
	breeding_mode_option.add_item("Probability Preview Only", 2)
	
	# Trait visibility
	trait_visibility_option.clear()
	trait_visibility_option.add_item("Both", 0)
	trait_visibility_option.add_item("Phenotype Only", 1)
	trait_visibility_option.add_item("Genotype Only", 2)
	
	# Punnett display mode
	punnett_mode_option.clear()
	punnett_mode_option.add_item("Full Grid", 0)
	punnett_mode_option.add_item("Collapsed Ratios", 1)
	punnett_mode_option.add_item("Single Gene Focus", 2)
	punnett_mode_option.add_item("Hidden", 3)
	
	# Naming mode
	naming_mode_option.clear()
	naming_mode_option.add_item("Generic (Human 001)", 0)
	naming_mode_option.add_item("Random First Names", 1)
	naming_mode_option.add_item("Custom Prefix", 2)


func _load_current_state() -> void:
	## Load current Teacher Mode state into controls
	
	active_toggle.button_pressed = TeacherModeState.is_active()
	
	# Genes
	var active_genes: Array = TeacherModeState.get_active_genes()
	for gene_id in _gene_checkboxes:
		_gene_checkboxes[gene_id].button_pressed = gene_id in active_genes
	lock_to_level_check.button_pressed = TeacherModeState.is_genes_locked_to_level()
	
	# Breeding
	max_genes_spin.value = TeacherModeState.get_max_genes_per_cross()
	lock_parents_check.button_pressed = TeacherModeState.are_parents_locked()
	allow_self_breeding_check.button_pressed = TeacherModeState.is_self_breeding_allowed()
	
	var breeding_mode: String = TeacherModeState.get_breeding_mode()
	match breeding_mode:
		"random": breeding_mode_option.select(0)
		"fixed": breeding_mode_option.select(1)
		"preview": breeding_mode_option.select(2)
		_: breeding_mode_option.select(0)
	
	# Visibility
	var trait_visibility: String = TeacherModeState.get_trait_visibility()
	match trait_visibility:
		"both": trait_visibility_option.select(0)
		"phenotype": trait_visibility_option.select(1)
		"genotype": trait_visibility_option.select(2)
		_: trait_visibility_option.select(0)
	
	var punnett_mode: String = TeacherModeState.get_punnett_display_mode()
	match punnett_mode:
		"full": punnett_mode_option.select(0)
		"ratios": punnett_mode_option.select(1)
		"single_gene": punnett_mode_option.select(2)
		"hidden": punnett_mode_option.select(3)
		_: punnett_mode_option.select(0)
	
	hide_alleles_check.button_pressed = TeacherModeState.should_hide_alleles()
	hide_dominance_check.button_pressed = TeacherModeState.should_hide_dominance_labels()
	low_spec_check.button_pressed = TeacherModeState.is_low_spec_mode()
	
	# Randomness
	deterministic_check.button_pressed = TeacherModeState.is_deterministic()
	seed_spin.value = TeacherModeState.get_random_seed()
	seed_spin.editable = deterministic_check.button_pressed
	new_seed_button.disabled = not deterministic_check.button_pressed
	disable_generation_check.button_pressed = TeacherModeState.is_generation_locked()
	
	# Ethics
	neutral_language_check.button_pressed = TeacherModeState.should_enforce_neutral_language()
	show_disclaimer_check.button_pressed = TeacherModeState.should_show_modeling_disclaimer()
	
	var naming_mode: String = TeacherModeState.get_naming_mode()
	match naming_mode:
		"generic": naming_mode_option.select(0)
		"random": naming_mode_option.select(1)
		"custom": naming_mode_option.select(2)
		_: naming_mode_option.select(1)
	
	custom_prefix_input.text = TeacherModeState.get_custom_naming_prefix()
	custom_prefix_hbox.visible = naming_mode == "custom"


func _apply_state() -> void:
	## Apply control values to Teacher Mode state
	
	TeacherModeState.set_active(active_toggle.button_pressed)
	
	# Genes
	var selected_genes: Array[String] = []
	for gene_id in _gene_checkboxes:
		if _gene_checkboxes[gene_id].button_pressed:
			selected_genes.append(gene_id)
	TeacherModeState.set_active_genes(selected_genes)
	TeacherModeState.set_lock_genes_to_level(lock_to_level_check.button_pressed)
	
	# Breeding
	TeacherModeState.set_max_genes_per_cross(int(max_genes_spin.value))
	TeacherModeState.set_lock_parents(lock_parents_check.button_pressed)
	TeacherModeState.set_allow_self_breeding(allow_self_breeding_check.button_pressed)
	
	var breeding_mode: String = "random"
	match breeding_mode_option.selected:
		0: breeding_mode = "random"
		1: breeding_mode = "fixed"
		2: breeding_mode = "preview"
	TeacherModeState.set_breeding_mode(breeding_mode)
	
	# Visibility
	var trait_visibility: String = "both"
	match trait_visibility_option.selected:
		0: trait_visibility = "both"
		1: trait_visibility = "phenotype"
		2: trait_visibility = "genotype"
	TeacherModeState.set_trait_visibility(trait_visibility)
	
	var punnett_mode: String = "full"
	match punnett_mode_option.selected:
		0: punnett_mode = "full"
		1: punnett_mode = "ratios"
		2: punnett_mode = "single_gene"
		3: punnett_mode = "hidden"
	TeacherModeState.set_punnett_display_mode(punnett_mode)
	
	TeacherModeState.set_hide_alleles(hide_alleles_check.button_pressed)
	TeacherModeState.set_hide_dominance_labels(hide_dominance_check.button_pressed)
	TeacherModeState.set_low_spec_mode(low_spec_check.button_pressed)
	
	# Randomness
	TeacherModeState.set_deterministic(deterministic_check.button_pressed)
	TeacherModeState.set_random_seed(int(seed_spin.value))
	TeacherModeState.set_allow_generation(not disable_generation_check.button_pressed)
	
	# Ethics
	TeacherModeState.set_enforce_neutral_language(neutral_language_check.button_pressed)
	TeacherModeState.set_show_modeling_disclaimer(show_disclaimer_check.button_pressed)
	
	var naming_mode: String = "random"
	match naming_mode_option.selected:
		0: naming_mode = "generic"
		1: naming_mode = "random"
		2: naming_mode = "custom"
	TeacherModeState.set_naming_mode(naming_mode)
	TeacherModeState.set_custom_naming_prefix(custom_prefix_input.text)


func show_panel() -> void:
	_load_current_state()
	visible = true
	tab_container.current_tab = 0


func hide_panel() -> void:
	visible = false
	panel_closed.emit()


func _on_close_pressed() -> void:
	hide_panel()


func _on_active_toggled(pressed: bool) -> void:
	# Live update active state
	TeacherModeState.set_active(pressed)


func _on_apply_pressed() -> void:
	_apply_state()
	hide_panel()


func _on_reset_defaults_pressed() -> void:
	TeacherModeState.reset_to_defaults()
	_load_current_state()


func _on_export_pressed() -> void:
	var snapshot: Dictionary = TeacherModeState.export_session_snapshot()
	snapshot_exported.emit(snapshot)
	
	# For now, print to console (could open file dialog)
	print("Session Snapshot Exported:")
	print(JSON.stringify(snapshot, "\t"))


func _on_session_reset_pressed() -> void:
	# Confirmation would be good here
	session_reset_requested.emit()


func _on_deterministic_toggled(pressed: bool) -> void:
	seed_spin.editable = pressed
	new_seed_button.disabled = not pressed


func _on_new_seed_pressed() -> void:
	seed_spin.value = randi()


func _on_naming_mode_changed(index: int) -> void:
	custom_prefix_hbox.visible = (index == 2)
