extends PanelContainer
class_name OffspringPreview
## Displays the result of recombination with option to save to library

signal offspring_saved(human_id: int)

@onready var face_container: CenterContainer = %FaceContainer
@onready var face_placeholder: ColorRect = %FacePlaceholder
@onready var eye_label: Label = %EyeLabel
@onready var skin_label: Label = %SkinLabel
@onready var hair_color_label: Label = %HairColorLabel
@onready var hair_texture_label: Label = %HairTextureLabel
@onready var genotype_container: VBoxContainer = %GenotypeContainer
@onready var genotype_label: Label = %GenotypeLabel
@onready var probability_container: VBoxContainer = %ProbabilityContainer
@onready var probability_list: VBoxContainer = %ProbabilityList
@onready var phenotype_container: VBoxContainer = %PhenotypeContainer
@onready var button_container: HBoxContainer = %ButtonContainer
@onready var unsaved_badge: Label = %UnsavedBadge
@onready var save_button: Button = %SaveButton
@onready var name_input: LineEdit = %NameInput
@onready var random_name_button: Button = %RandomNameButton
@onready var confirm_button: Button = %ConfirmButton
@onready var cancel_button: Button = %CancelButton

const HumanFaceScene := preload("res://scenes/humans/HumanFace.tscn")

var current_offspring_data: Dictionary = {}
var face_instance: Node = null
var _naming_mode: bool = false


func _ready() -> void:
	save_button.pressed.connect(_on_save_pressed)
	random_name_button.pressed.connect(_on_random_name_pressed)
	confirm_button.pressed.connect(_on_confirm_pressed)
	cancel_button.pressed.connect(_on_cancel_pressed)
	name_input.text_submitted.connect(_on_name_submitted)
	
	# Start in empty state
	_show_empty_state()


func _show_empty_state() -> void:
	phenotype_container.visible = false
	genotype_container.visible = false
	probability_container.visible = false
	save_button.visible = false
	if unsaved_badge:
		unsaved_badge.visible = false
	_exit_naming_mode()
	
	face_placeholder.visible = true
	
	_update_phenotype_labels({})
	genotype_label.text = "--"
	
	if face_instance:
		face_instance.queue_free()
		face_instance = null
	
	current_offspring_data = {}


func show_offspring(offspring_data: Dictionary) -> void:
	current_offspring_data = offspring_data.duplicate(true)
	
	probability_container.visible = false
	phenotype_container.visible = true
	# Hide genotype details when Teacher Mode limits visibility.
	genotype_container.visible = TeacherModeState.get_trait_visibility() != "phenotype"
	save_button.visible = true
	if unsaved_badge:
		unsaved_badge.visible = true
	_exit_naming_mode()
	
	# Render face
	if face_instance:
		face_instance.queue_free()
	
	face_placeholder.visible = false
	face_instance = HumanFaceScene.instantiate()
	face_container.add_child(face_instance)
	
	var phenotype: Dictionary = offspring_data.get("phenotype", {})
	if face_instance.has_method("render"):
		face_instance.render(phenotype)
	elif face_instance.has_method("render_phenotype"):
		face_instance.render_phenotype(phenotype)
	
	# Update labels
	_update_phenotype_labels(phenotype)
	_update_genotype_label(offspring_data.get("genotype", {}))


func show_probability_preview(ratios: Dictionary) -> void:
	## Display phenotype ratios instead of a single offspring
	## ratios format: {"eye_color": {"brown": 0.25, "blue": 0.75}, ...}
	
	current_offspring_data = {}
	
	phenotype_container.visible = false
	genotype_container.visible = false
	save_button.visible = false
	if unsaved_badge:
		unsaved_badge.visible = false
	_exit_naming_mode()
	probability_container.visible = true
	
	if face_instance:
		face_instance.queue_free()
		face_instance = null
	face_placeholder.visible = true
	
	# Clear and populate probability list
	for child in probability_list.get_children():
		child.queue_free()
	
	for trait_name in ratios:
		var trait_ratios: Dictionary = ratios[trait_name]
		
		# Trait header
		var header := Label.new()
		header.text = _format_trait_name(trait_name) + ":"
		header.add_theme_font_size_override("font_size", 12)
		header.add_theme_color_override("font_color", Color(0.9, 0.9, 0.9))
		probability_list.add_child(header)
		
		# Sort by percentage descending
		var sorted_phenotypes := trait_ratios.keys()
		sorted_phenotypes.sort_custom(func(a, b): return trait_ratios[a] > trait_ratios[b])
		
		for phenotype in sorted_phenotypes:
			var percentage: float = trait_ratios[phenotype] * 100.0
			if percentage < 0.5:
				continue  # Skip very rare outcomes
			
			var entry := HBoxContainer.new()
			
			var name_label := Label.new()
			name_label.text = "  " + _format_phenotype_name(phenotype)
			name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			entry.add_child(name_label)
			
			var percent_label := Label.new()
			percent_label.text = "%.1f%%" % percentage
			percent_label.add_theme_color_override("font_color", Color(0.7, 0.7, 0.7))
			entry.add_child(percent_label)
			
			probability_list.add_child(entry)
		
		# Separator between traits
		var sep := HSeparator.new()
		probability_list.add_child(sep)


func _update_phenotype_labels(phenotype: Dictionary) -> void:
	var displayed_traits: Array = HumanGeneticsState.get_traits_displayed()
	
	eye_label.visible = "eye_color" in displayed_traits
	skin_label.visible = "skin_tone" in displayed_traits
	hair_color_label.visible = "hair_color" in displayed_traits
	hair_texture_label.visible = "hair_texture" in displayed_traits
	
	if eye_label.visible:
		if phenotype.has("eye_color"):
			eye_label.text = "Eyes: " + _format_phenotype_name(phenotype.eye_color)
		else:
			eye_label.text = "Eyes: --"
	
	if skin_label.visible:
		if phenotype.has("skin_tone"):
			skin_label.text = "Skin: " + _format_phenotype_name(phenotype.skin_tone)
		else:
			skin_label.text = "Skin: --"
	
	if hair_color_label.visible:
		if phenotype.has("hair_color"):
			hair_color_label.text = "Hair: " + _format_phenotype_name(phenotype.hair_color)
		else:
			hair_color_label.text = "Hair: --"
	
	if hair_texture_label.visible:
		if phenotype.has("hair_texture"):
			hair_texture_label.text = "Texture: " + _format_phenotype_name(phenotype.hair_texture)
		else:
			hair_texture_label.text = "Texture: --"


func _update_genotype_label(genotype: Dictionary) -> void:
	var parts: Array[String] = []
	var active_genes: Array = TeacherModeState.get_active_genes()
	
	for gene_id in active_genes:
		if not TeacherModeState.is_gene_visible(gene_id):
			continue
		if genotype.has(gene_id):
			var alleles: Array = genotype[gene_id]
			parts.append(gene_id + ": " + _format_allele_pair(alleles, gene_id))
	
	genotype_label.text = " | ".join(parts) if parts.size() > 0 else "--"


func _format_allele_pair(alleles: Array, gene_id: String) -> String:
	if alleles.size() < 2:
		return "??"
	
	var gene_info: Dictionary = HumanGeneticsState.get_gene_info(gene_id)
	if gene_info.is_empty():
		return str(alleles[0]) + str(alleles[1])
	
	var dom: String = gene_info.get("dom", "")
	var rec: String = gene_info.get("rec", "")
	
	if dom != "" and rec != "" and dom in alleles and rec in alleles:
		return dom + rec
	
	return str(alleles[0]) + str(alleles[1])


func _format_phenotype_name(raw: String) -> String:
	## Convert "dark_brown" to "Dark Brown"
	return raw.replace("_", " ").capitalize()


func _format_trait_name(raw: String) -> String:
	return raw.replace("_", " ").capitalize()


func _enter_naming_mode() -> void:
	_naming_mode = true
	save_button.visible = false
	name_input.visible = true
	random_name_button.visible = true
	confirm_button.visible = true
	cancel_button.visible = true
	name_input.text = HumanGeneticsState.generate_random_name()
	name_input.grab_focus()
	name_input.select_all()


func _exit_naming_mode() -> void:
	_naming_mode = false
	name_input.visible = false
	random_name_button.visible = false
	confirm_button.visible = false
	cancel_button.visible = false


func _on_save_pressed() -> void:
	if current_offspring_data.is_empty():
		return
	_enter_naming_mode()


func _on_random_name_pressed() -> void:
	name_input.text = HumanGeneticsState.generate_random_name()
	name_input.grab_focus()
	name_input.select_all()


func _on_confirm_pressed() -> void:
	_save_offspring()


func _on_name_submitted(_new_text: String) -> void:
	_save_offspring()


func _on_cancel_pressed() -> void:
	_exit_naming_mode()
	save_button.visible = true


func _save_offspring() -> void:
	if current_offspring_data.is_empty():
		return
	
	var human_name: String = name_input.text.strip_edges()
	if human_name.is_empty():
		human_name = HumanGeneticsState.generate_random_name()
	
	var human_id: int = HumanGeneticsState.add_human(
		current_offspring_data.get("genotype", {}),
		human_name,
		current_offspring_data.get("generation", 1),
		current_offspring_data.get("parent_a_id", -1),
		current_offspring_data.get("parent_b_id", -1)
	)
	
	offspring_saved.emit(human_id)
	
	# Reset to empty state after save
	_show_empty_state()


func clear() -> void:
	_show_empty_state()
