# BreedingArea.gd
# Central breeding workspace with parent slots, Punnett square, and offspring preview
# Supports drag-drop parent selection and in-place genotype editing
# Educational purpose: Demonstrate Mendelian inheritance and recombination

extends PanelContainer

# ============================================================================
# SIGNALS
# ============================================================================

signal offspring_created(human_id: int)
signal parent_selected(slot: String, human_id: int)

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var parent_a_slot: Control = $VBox/HBoxContainer/VBoxContainer/ParentsContainer/ParentASlot
@onready var parent_b_slot: Control = $VBox/HBoxContainer/VBoxContainer/ParentsContainer/ParentBSlot
@onready var punnett_grid: Control = $VBox/HBoxContainer/VBoxContainer2/PunnettContainer/PunnettGrid
@onready var recombine_button: Button = $VBox/HBoxContainer/VBoxContainer2/RecombineButton
@onready var offspring_preview: Control = $VBox/OffspringPreview
@onready var allele_palette: Control = $VBox/HBoxContainer/VBoxContainer/AllelePalette

# ============================================================================
# STATE
# ============================================================================

var _parent_a_id: int = -1
var _parent_b_id: int = -1
var _parent_a_genotype: Dictionary = {}  # Working genotype (may differ from saved)
var _parent_b_genotype: Dictionary = {}
var _current_offspring_id: int = -1
var _parents_locked: bool = false

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_connections()
	_update_ui_state()


func _setup_connections() -> void:
	# Parent slot signals
	if parent_a_slot:
		parent_a_slot.human_dropped.connect(_on_parent_a_dropped)
		parent_a_slot.genotype_changed.connect(_on_parent_a_genotype_changed)
		parent_a_slot.cleared.connect(_on_parent_a_cleared)
	
	if parent_b_slot:
		parent_b_slot.human_dropped.connect(_on_parent_b_dropped)
		parent_b_slot.genotype_changed.connect(_on_parent_b_genotype_changed)
		parent_b_slot.cleared.connect(_on_parent_b_cleared)
	
	# Recombine button
	recombine_button.pressed.connect(_on_recombine_pressed)
	
	# Offspring preview
	if offspring_preview:
		offspring_preview.offspring_saved.connect(_on_offspring_saved)
	
	# Teacher mode changes
	TeacherModeState.constraints_changed.connect(_on_teacher_constraints_changed)


# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Set a parent from the library panel
func set_parent_from_library(human_id: int, slot: String) -> void:
	if _parents_locked and TeacherModeState.are_parents_locked():
		_show_locked_feedback(slot)
		return
	
	var human := HumanGeneticsState.get_human(human_id)
	if human.is_empty():
		return
	
	if slot == "A" or slot == "parent_a":
		_set_parent_a(human_id, human.get("genotype", {}))
	elif slot == "B" or slot == "parent_b":
		_set_parent_b(human_id, human.get("genotype", {}))


## Refresh the entire breeding area
func refresh() -> void:
	_update_punnett_square()
	_update_ui_state()
	
	if parent_a_slot:
		parent_a_slot.refresh()
	if parent_b_slot:
		parent_b_slot.refresh()
	if allele_palette:
		allele_palette.refresh()


## Called when level changes
func on_level_changed(_level_id: int) -> void:
	# Clear current state
	_clear_parents()
	_clear_offspring()
	refresh()
	
	# Update allele palette with new active genes
	if allele_palette:
		allele_palette.setup_for_level()


# ============================================================================
# PARENT MANAGEMENT
# ============================================================================

func _set_parent_a(human_id: int, genotype: Dictionary) -> void:
	_parent_a_id = human_id
	_parent_a_genotype = HumanGeneticsState.normalize_genotype(genotype)
	
	if parent_a_slot:
		parent_a_slot.set_human(human_id, _parent_a_genotype)
	
	parent_selected.emit("A", human_id)
	_on_parents_changed()


func _set_parent_b(human_id: int, genotype: Dictionary) -> void:
	_parent_b_id = human_id
	_parent_b_genotype = HumanGeneticsState.normalize_genotype(genotype)
	
	if parent_b_slot:
		parent_b_slot.set_human(human_id, _parent_b_genotype)
	
	parent_selected.emit("B", human_id)
	_on_parents_changed()


func _clear_parents() -> void:
	_parent_a_id = -1
	_parent_b_id = -1
	_parent_a_genotype = {}
	_parent_b_genotype = {}
	_parents_locked = false
	
	if parent_a_slot:
		parent_a_slot.clear()
	if parent_b_slot:
		parent_b_slot.clear()
	
	_on_parents_changed()


func _clear_offspring() -> void:
	_current_offspring_id = -1
	if offspring_preview:
		offspring_preview.clear()


func _on_parents_changed() -> void:
	_update_punnett_square()
	_update_ui_state()
	_clear_offspring()


# ============================================================================
# EVENT HANDLERS - PARENT SLOTS
# ============================================================================

func _on_parent_a_dropped(human_id: int) -> void:
	if _parents_locked and TeacherModeState.are_parents_locked():
		_show_locked_feedback("A")
		return
	
	var human := HumanGeneticsState.get_human(human_id)
	if not human.is_empty():
		_set_parent_a(human_id, human.get("genotype", {}))


func _on_parent_b_dropped(human_id: int) -> void:
	if _parents_locked and TeacherModeState.are_parents_locked():
		_show_locked_feedback("B")
		return
	
	var human := HumanGeneticsState.get_human(human_id)
	if not human.is_empty():
		_set_parent_b(human_id, human.get("genotype", {}))


func _on_parent_a_genotype_changed(new_genotype: Dictionary) -> void:
	_parent_a_genotype = new_genotype
	# Mark as modified (no longer linked to original human)
	if _parent_a_id > 0:
		_parent_a_id = -1  # Detach from saved human
	_on_parents_changed()


func _on_parent_b_genotype_changed(new_genotype: Dictionary) -> void:
	_parent_b_genotype = new_genotype
	if _parent_b_id > 0:
		_parent_b_id = -1
	_on_parents_changed()


func _on_parent_a_cleared() -> void:
	_parent_a_id = -1
	_parent_a_genotype = {}
	_on_parents_changed()


func _on_parent_b_cleared() -> void:
	_parent_b_id = -1
	_parent_b_genotype = {}
	_on_parents_changed()


# ============================================================================
# PUNNETT SQUARE
# ============================================================================

func _update_punnett_square() -> void:
	if not punnett_grid:
		return
	
	# Check if both parents have genotypes
	if _parent_a_genotype.is_empty() or _parent_b_genotype.is_empty():
		punnett_grid.clear()
		return
	
	# Get active genes for current level
	var active_genes := HumanGeneticsState.get_active_genes()
	
	# Limit genes based on max genes per cross
	var max_genes := TeacherModeState.get_max_genes_per_cross()
	var genes_to_show: Array = active_genes.slice(0, min(active_genes.size(), max_genes))
	
	# Check display mode
	var display_mode := TeacherModeState.get_punnett_display_mode()
	
	match display_mode:
		"hidden":
			punnett_grid.clear()
		"ratios":
			punnett_grid.display_ratios(_parent_a_genotype, _parent_b_genotype, genes_to_show)
		"single_gene":
			if genes_to_show.size() > 0:
				punnett_grid.display_single_gene(_parent_a_genotype, _parent_b_genotype, genes_to_show[0])
		_:  # "full"
			punnett_grid.display_full(_parent_a_genotype, _parent_b_genotype, genes_to_show)


# ============================================================================
# RECOMBINATION
# ============================================================================

func _on_recombine_pressed() -> void:
	if _parent_a_genotype.is_empty() or _parent_b_genotype.is_empty():
		return
	
	# Check breeding mode
	var breeding_mode := TeacherModeState.get_breeding_mode()
	
	if breeding_mode == "preview":
		# Show probability preview only, no offspring created
		_show_probability_preview()
		return
	
	# Lock parents if setting is enabled
	if TeacherModeState.are_parents_locked():
		_parents_locked = true
	
	# Create temporary parents if needed
	var parent_a_id := _parent_a_id
	var parent_b_id := _parent_b_id
	
	if parent_a_id < 0:
		# Save temporary parent
		parent_a_id = HumanGeneticsState.add_human(_parent_a_genotype, "Temp Parent A", 0)
	if parent_b_id < 0:
		parent_b_id = HumanGeneticsState.add_human(_parent_b_genotype, "Temp Parent B", 0)
	
	# Perform breeding
	var selected_cell: int = -1
	if breeding_mode == "fixed":
		selected_cell = TeacherModeState.get_fixed_cell_index()
	
	var offspring_id := HumanGeneticsState.breed(parent_a_id, parent_b_id, selected_cell)
	
	if offspring_id > 0:
		_current_offspring_id = offspring_id
		_show_offspring(offspring_id)
		offspring_created.emit(offspring_id)


func _show_offspring(human_id: int) -> void:
	if not offspring_preview:
		return
	
	var human := HumanGeneticsState.get_human(human_id)
	if not human.is_empty():
		offspring_preview.show_offspring(human)


func _show_probability_preview() -> void:
	# Calculate probability distribution from Punnett square
	# This shows expected ratios without creating an offspring
	if not offspring_preview:
		return
	
	var active_genes := HumanGeneticsState.get_active_genes()
	var max_genes := TeacherModeState.get_max_genes_per_cross()
	var genes_to_use: Array = active_genes.slice(0, min(active_genes.size(), max_genes))
	
	# Build Punnett square manually
	var gametes_a := HumanGeneticsState.build_gametes(_parent_a_genotype, genes_to_use)
	var gametes_b := HumanGeneticsState.build_gametes(_parent_b_genotype, genes_to_use)
	
	# Calculate phenotype frequencies by trait
	# Format: {"eye_color": {"brown": 0.25, "blue": 0.75}, "skin_tone": {...}}
	var trait_counts: Dictionary = {}
	var total := 0
	
	for ga in gametes_a:
		for gb in gametes_b:
			var combined := {}
			for gene in genes_to_use:
				combined[gene] = [ga.get(gene, ""), gb.get(gene, "")]
			combined = HumanGeneticsState.apply_convenience_genotypes(combined)
			
			var phenotype := HumanGeneticsState.calculate_phenotype(combined)
			
			# Count each trait's phenotype
			for trait_name in phenotype:
				if not trait_counts.has(trait_name):
					trait_counts[trait_name] = {}
				var trait_value: String = phenotype[trait_name]
				if not trait_counts[trait_name].has(trait_value):
					trait_counts[trait_name][trait_value] = 0
				trait_counts[trait_name][trait_value] += 1
			
			total += 1
	
	# Convert counts to ratios
	var phenotype_ratios: Dictionary = {}
	for trait_name in trait_counts:
		phenotype_ratios[trait_name] = {}
		for trait_value in trait_counts[trait_name]:
			phenotype_ratios[trait_name][trait_value] = float(trait_counts[trait_name][trait_value]) / float(total)
	
	offspring_preview.show_probability_preview(phenotype_ratios)


func _on_offspring_saved(human_id: int) -> void:
	# Offspring was saved to library, notify parent
	offspring_created.emit(human_id)


# ============================================================================
# UI STATE
# ============================================================================

func _update_ui_state() -> void:
	# Update recombine button
	var can_recombine := not _parent_a_genotype.is_empty() and not _parent_b_genotype.is_empty()
	recombine_button.disabled = not can_recombine
	
	# Update button text based on mode
	var breeding_mode := TeacherModeState.get_breeding_mode()
	if breeding_mode == "preview":
		recombine_button.text = "Show Probabilities"
	else:
		recombine_button.text = "Recombine"


func _show_locked_feedback(slot: String) -> void:
	var target_slot: Control = parent_a_slot if slot == "A" else parent_b_slot
	if target_slot:
		target_slot.modulate = Color.RED
		var tween := create_tween()
		tween.tween_property(target_slot, "modulate", Color.WHITE, 0.3)


func _on_teacher_constraints_changed() -> void:
	refresh()
