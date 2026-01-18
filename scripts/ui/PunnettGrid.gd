# PunnettGrid.gd
# Dynamic Punnett square display for genetics crosses
# Supports monohybrid (2x2), dihybrid (4x4), and ratio views
# Educational purpose: Visualize genetic inheritance patterns

extends Control

# ============================================================================
# SIGNALS
# ============================================================================

signal cell_clicked(index: int, genotype: Dictionary)

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var grid_container: GridContainer = $VBox/GridContainer
@onready var empty_label: Label = $VBox/MessageLabel
@onready var ratios_label: Label = $VBox/RatioPanel/RatioVBox/RatioTitle

# ============================================================================
# CONSTANTS
# ============================================================================

const CELL_SIZE := Vector2(60, 60)
const CELL_SIZE_SMALL := Vector2(45, 45)

# ============================================================================
# STATE
# ============================================================================

var _punnett_data: Array = []
var _genes_shown: Array = []
var _parent_a_genotype: Dictionary = {}
var _parent_b_genotype: Dictionary = {}

# ============================================================================
# PUBLIC INTERFACE
# ============================================================================

## Clear the Punnett square
func clear() -> void:
	_clear_grid()
	_punnett_data = []
	_genes_shown = []
	
	if empty_label:
		empty_label.visible = true
		empty_label.text = "Select parents to show\nPunnett square"
	if ratios_label:
		ratios_label.visible = false


## Display full Punnett square
func display_full(genotype_a: Dictionary, genotype_b: Dictionary, genes: Array) -> void:
	_parent_a_genotype = genotype_a
	_parent_b_genotype = genotype_b
	_genes_shown = genes
	
	if empty_label:
		empty_label.visible = false
	if ratios_label:
		ratios_label.visible = false
	
	# Build gametes
	var gametes_a := HumanGeneticsState.build_gametes(genotype_a, genes)
	var gametes_b := HumanGeneticsState.build_gametes(genotype_b, genes)
	
	_build_grid(gametes_a, gametes_b, genes)


## Display collapsed ratios view
func display_ratios(genotype_a: Dictionary, genotype_b: Dictionary, genes: Array) -> void:
	_parent_a_genotype = genotype_a
	_parent_b_genotype = genotype_b
	_genes_shown = genes
	
	_clear_grid()
	
	if empty_label:
		empty_label.visible = false
	if ratios_label:
		ratios_label.visible = true
	
	# Calculate phenotype ratios
	var ratios := _calculate_phenotype_ratios(genotype_a, genotype_b, genes)
	
	if ratios_label:
		ratios_label.text = _format_ratios(ratios)


## Display single-gene focus view
func display_single_gene(genotype_a: Dictionary, genotype_b: Dictionary, gene_id: String) -> void:
	display_full(genotype_a, genotype_b, [gene_id])


# ============================================================================
# GRID BUILDING
# ============================================================================

func _clear_grid() -> void:
	if not grid_container:
		return
	
	for child in grid_container.get_children():
		child.queue_free()


func _build_grid(gametes_a: Array, gametes_b: Array, genes: Array) -> void:
	_clear_grid()
	
	if not grid_container:
		return
	
	var grid_size: int = gametes_a.size()
	grid_container.columns = grid_size + 1  # +1 for row headers
	
	var cell_size := CELL_SIZE if grid_size <= 4 else CELL_SIZE_SMALL
	var low_spec := TeacherModeState.is_low_spec_mode()
	
	# Header row (empty corner + gametes_a)
	var corner := _create_header_cell("")
	grid_container.add_child(corner)
	
	for gamete in gametes_a:
		var header := _create_header_cell(_format_gamete(gamete))
		grid_container.add_child(header)
	
	# Data rows
	_punnett_data = []
	var cell_index := 0
	
	for gamete_b in gametes_b:
		# Row header
		var row_header := _create_header_cell(_format_gamete(gamete_b))
		grid_container.add_child(row_header)
		
		# Data cells
		for gamete_a in gametes_a:
			var offspring_genotype := _combine_gametes(gamete_a, gamete_b)
			offspring_genotype = HumanGeneticsState.apply_convenience_genotypes(offspring_genotype)
			_punnett_data.append(offspring_genotype)
			
			var cell := _create_data_cell(offspring_genotype, cell_index, cell_size, low_spec)
			grid_container.add_child(cell)
			cell_index += 1


func _create_header_cell(text: String) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(50, 25)
	
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.25, 0.27, 0.3)
	panel.add_theme_stylebox_override("panel", style)
	
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 10)
	panel.add_child(label)
	
	return panel


func _create_data_cell(genotype: Dictionary, index: int, cell_size: Vector2, low_spec: bool) -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = cell_size
	
	# Calculate phenotype for color
	var phenotype := HumanGeneticsState.calculate_phenotype(genotype)
	var bg_color := _phenotype_to_cell_color(phenotype)
	
	var style := StyleBoxFlat.new()
	style.bg_color = bg_color
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = Color(0.4, 0.42, 0.45)
	panel.add_theme_stylebox_override("panel", style)
	
	var vbox := VBoxContainer.new()
	vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	panel.add_child(vbox)
	
	# Genotype label
	if TeacherModeState.should_show_genotype():
		var genotype_label := Label.new()
		genotype_label.text = _format_genotype_short(genotype)
		genotype_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		genotype_label.add_theme_font_size_override("font_size", 9)
		vbox.add_child(genotype_label)
	
	# Make clickable
	panel.gui_input.connect(func(event):
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			cell_clicked.emit(index, genotype)
	)
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	
	return panel


func _format_gamete(gamete: Dictionary) -> String:
	var parts: Array = []
	for gene in _genes_shown:
		if gamete.has(gene):
			parts.append(gamete[gene])
	return "".join(parts)


func _format_genotype_short(genotype: Dictionary) -> String:
	var parts: Array = []
	for gene in _genes_shown:
		if genotype.has(gene):
			var alleles: Array = genotype[gene]
			if alleles.size() >= 2:
				parts.append(alleles[0] + alleles[1])
	return " ".join(parts)


func _combine_gametes(gamete_a: Dictionary, gamete_b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for gene in _genes_shown:
		var a: String = gamete_a.get(gene, "")
		var b: String = gamete_b.get(gene, "")
		result[gene] = [a, b]
	return result


func _phenotype_to_cell_color(phenotype: Dictionary) -> Color:
	# Use eye color as primary indicator
	var eye_color: String = phenotype.get("eye_color", "medium_brown")
	var base_color := HumanGeneticsState.get_eye_color(eye_color)
	
	# Make it a subtle background tint
	return base_color.lerp(Color(0.2, 0.22, 0.25), 0.7)


# ============================================================================
# RATIO CALCULATIONS
# ============================================================================

func _calculate_phenotype_ratios(genotype_a: Dictionary, genotype_b: Dictionary, genes: Array) -> Dictionary:
	var gametes_a := HumanGeneticsState.build_gametes(genotype_a, genes)
	var gametes_b := HumanGeneticsState.build_gametes(genotype_b, genes)
	
	var phenotype_counts: Dictionary = {}
	var total := 0
	
	for ga in gametes_a:
		for gb in gametes_b:
			var combined := _combine_gametes(ga, gb)
			combined = HumanGeneticsState.apply_convenience_genotypes(combined)
			var phenotype := HumanGeneticsState.calculate_phenotype(combined)
			
			# Create key from displayed traits
			var key := _phenotype_to_key(phenotype)
			if not phenotype_counts.has(key):
				phenotype_counts[key] = {"count": 0, "phenotype": phenotype}
			phenotype_counts[key]["count"] += 1
			total += 1
	
	# Convert to ratios
	var ratios: Dictionary = {}
	for key in phenotype_counts.keys():
		var data: Dictionary = phenotype_counts[key]
		ratios[key] = {
			"phenotype": data["phenotype"],
			"fraction": float(data["count"]) / float(total),
			"count": data["count"],
			"total": total
		}
	
	return ratios


func _phenotype_to_key(phenotype: Dictionary) -> String:
	var displayed_traits := HumanGeneticsState.get_traits_displayed()
	var parts: Array = []
	for spec_trait in displayed_traits:
		if phenotype.has(spec_trait):
			parts.append(phenotype[spec_trait])
	return "_".join(parts)


func _format_ratios(ratios: Dictionary) -> String:
	var lines: Array = []
	lines.append("Phenotype Ratios:")
	lines.append("")
	
	# Sort by count (descending)
	var sorted_keys: Array = ratios.keys()
	sorted_keys.sort_custom(func(a, b): return ratios[a]["count"] > ratios[b]["count"])
	
	for key in sorted_keys:
		var data: Dictionary = ratios[key]
		var phenotype: Dictionary = data["phenotype"]
		var count: int = data["count"]
		var total: int = data["total"]
		var percentage: float = data["fraction"] * 100.0
		
		var traits_text := _format_phenotype_brief(phenotype)
		lines.append("%s: %d/%d (%.1f%%)" % [traits_text, count, total, percentage])
	
	return "\n".join(lines)


func _format_phenotype_brief(phenotype: Dictionary) -> String:
	var displayed_traits := HumanGeneticsState.get_traits_displayed()
	var parts: Array = []
	
	for spec_trait in displayed_traits:
		if phenotype.has(spec_trait):
			var value: String = phenotype[spec_trait]
			# Shorten the value
			value = value.replace("_", " ").split(" ")[0].capitalize()
			parts.append(value)
	
	return ", ".join(parts)
