# HumanFace.gd
# Renders a human face using layered, color-modulated sprites
# Uses placeholder colored rectangles until real assets are provided
# Educational purpose: Visual representation of phenotype from genotype

extends Control

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var base_layer: ColorRect = $Layers/BaseLayer
@onready var skin_layer: ColorRect = $Layers/SkinLayer
@onready var eye_whites: ColorRect = $Layers/EyeWhites
@onready var iris_left: ColorRect = $Layers/IrisLeft
@onready var iris_right: ColorRect = $Layers/IrisRight
@onready var hair_layer: ColorRect = $Layers/HairLayer
@onready var freckle_layer: ColorRect = $Layers/FreckleLayer

# ============================================================================
# STATE
# ============================================================================

var _current_phenotype: Dictionary = {}
var _cached_key: String = ""

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_default_appearance()


func _setup_default_appearance() -> void:
	# Set default placeholder colors
	if base_layer:
		base_layer.color = Color(0.3, 0.3, 0.35)  # Dark background
	if skin_layer:
		skin_layer.color = Color(0.9, 0.8, 0.7)  # Default skin
	if eye_whites:
		eye_whites.color = Color.WHITE
	if iris_left:
		iris_left.color = Color(0.4, 0.3, 0.2)  # Default brown
	if iris_right:
		iris_right.color = Color(0.4, 0.3, 0.2)
	if hair_layer:
		hair_layer.color = Color(0.2, 0.15, 0.1)  # Default dark hair
	if freckle_layer:
		freckle_layer.visible = false


# ============================================================================
# RENDERING
# ============================================================================

## Render a face from phenotype dictionary
func render(phenotype: Dictionary) -> void:
	# Check cache
	var cache_key := _phenotype_to_cache_key(phenotype)
	if cache_key == _cached_key:
		return  # Already rendered
	
	_current_phenotype = phenotype
	_cached_key = cache_key
	
	_apply_eye_color(phenotype.get("eye_color", "medium_brown"))
	_apply_skin_tone(phenotype.get("skin_tone", "medium"))
	_apply_hair_color(phenotype.get("hair_color", "medium_brown"))
	_apply_hair_texture(phenotype.get("hair_texture", "straight"))


func _phenotype_to_cache_key(phenotype: Dictionary) -> String:
	# Include Teacher Mode visibility flags in cache key
	var parts: Array = [
		phenotype.get("eye_color", ""),
		phenotype.get("skin_tone", ""),
		phenotype.get("hair_color", ""),
		phenotype.get("hair_texture", ""),
		str(TeacherModeState.is_low_spec_mode())
	]
	return "_".join(parts)


func _apply_eye_color(eye_color: String) -> void:
	var color := HumanGeneticsState.get_eye_color(eye_color)
	
	if iris_left:
		iris_left.color = color
	if iris_right:
		iris_right.color = color
	
	# Special handling for albino - pinkish eye whites
	if eye_color == "albino_pink" and eye_whites:
		eye_whites.color = Color(1.0, 0.94, 0.94)  # Slight pink tint
	elif eye_whites:
		eye_whites.color = Color.WHITE


func _apply_skin_tone(skin_tone: String) -> void:
	var color := HumanGeneticsState.get_skin_color(skin_tone)
	
	if skin_layer:
		skin_layer.color = color
	
	# Handle freckles
	var has_freckles := HumanGeneticsState.has_freckles(skin_tone)
	if freckle_layer:
		freckle_layer.visible = has_freckles
		if has_freckles:
			# Freckle color slightly darker than skin
			freckle_layer.color = color.darkened(0.2)


func _apply_hair_color(hair_color: String) -> void:
	var color := HumanGeneticsState.get_hair_color(hair_color)
	
	if hair_layer:
		hair_layer.color = color


func _apply_hair_texture(hair_texture: String) -> void:
	# For now, hair texture affects the shape/position slightly
	# In full implementation, this would swap sprite textures
	if not hair_layer:
		return
	
	match hair_texture:
		"straight":
			# Default shape
			pass
		"wavy":
			# Slightly different shape (placeholder effect)
			pass
		"curly":
			# Different shape (placeholder effect)
			pass


## Clear the face display
func clear() -> void:
	_current_phenotype = {}
	_cached_key = ""
	_setup_default_appearance()


## Get the current phenotype
func get_phenotype() -> Dictionary:
	return _current_phenotype
