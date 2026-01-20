# HumanFace.gd
# Renders a human face using layered, color-modulated sprites
# Uses placeholder colored rectangles until real assets are provided
# Educational purpose: Visual representation of phenotype from genotype

extends Control

# ============================================================================
# NODE REFERENCES
# ============================================================================

@onready var base_layer: ColorRect = $Layers/BaseLayer
@onready var skin_layer: Sprite2D = $Layers/Neck 
@onready var eye_whites: Sprite2D = $Layers/EyeL
@onready var iris_left: Sprite2D = $Layers/IrisL
@onready var iris_right: Sprite2D = $Layers/IrisR
@onready var hair_layer: Sprite2D = $Layers/Hair
@onready var lash_left: Sprite2D = $Layers/LashL
@onready var lash_right: Sprite2D = $Layers/LashR
@onready var freckle_layer: Sprite2D = $Layers/Freckles

# ============================================================================
# STATE
# ============================================================================

var _current_phenotype: Dictionary = {}
var _cached_key: String = ""
const TINT_DARKEN := 0.15
const HAIR_TEX_STRAIGHT := preload("res://assets/face/hair_straight.png")
const HAIR_TEX_WAVY := preload("res://assets/face/hair_wavy.png")
const HAIR_TEX_CURLY := preload("res://assets/face/hair_curly.png")

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	_setup_default_appearance()


func _setup_default_appearance() -> void:
	# Set default placeholder colors
	if base_layer:
		base_layer.modulate = Color(0.3, 0.3, 0.35)  # Dark background
	if skin_layer:
		skin_layer.modulate = _tint(Color(0.9, 0.8, 0.7))  # Default skin
	if eye_whites:
		eye_whites.modulate = Color.WHITE
	if iris_left:
		iris_left.modulate = _tint(Color(0.4, 0.3, 0.2))  # Default brown
	if iris_right:
		iris_right.modulate = _tint(Color(0.4, 0.3, 0.2))
	if hair_layer:
		hair_layer.texture = HAIR_TEX_STRAIGHT
		hair_layer.modulate = _tint(Color(0.2, 0.15, 0.1))  # Default dark hair
	if lash_left:
		lash_left.modulate = Color(1, 1, 1, 1)
	if lash_right:
		lash_right.modulate = Color(1, 1, 1, 1)
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
	_apply_lash_tint(phenotype)


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
		iris_left.modulate = _tint(color)
	if iris_right:
		iris_right.modulate = _tint(color)
	
	# Special handling for albino - pinkish eye whites
	if eye_color == "albino_pink" and eye_whites:
		eye_whites.modulate = Color(1.0, 0.94, 0.94)  # Slight pink tint
	elif eye_whites:
		eye_whites.modulate = Color.WHITE


func _apply_skin_tone(skin_tone: String) -> void:
	var color := HumanGeneticsState.get_skin_color(skin_tone)
	
	if skin_layer:
		skin_layer.modulate = _tint(color)
	
	# Handle freckles
	var has_freckles := HumanGeneticsState.has_freckles(skin_tone)
	if freckle_layer:
		freckle_layer.visible = has_freckles
		if has_freckles:
			# Freckle color slightly darker than skin
			freckle_layer.modulate = _tint(color.darkened(0.2))


func _apply_hair_color(hair_color: String) -> void:
	var color := HumanGeneticsState.get_hair_color(hair_color)
	
	if hair_layer:
		hair_layer.modulate = _tint(color)


func _apply_hair_texture(hair_texture: String) -> void:
	# For now, hair texture affects the shape/position slightly
	# In full implementation, this would swap sprite textures
	if not hair_layer:
		return
	
	match hair_texture:
		"straight":
			hair_layer.texture = HAIR_TEX_STRAIGHT
		"wavy":
			hair_layer.texture = HAIR_TEX_WAVY
		"curly":
			hair_layer.texture = HAIR_TEX_CURLY
		_:
			hair_layer.texture = HAIR_TEX_STRAIGHT


func _apply_lash_tint(phenotype: Dictionary) -> void:
	if not lash_left and not lash_right:
		return
	
	var eye_color: String = phenotype.get("eye_color", "")
	var skin_tone: String = phenotype.get("skin_tone", "")
	var severity := 0.0
	
	if eye_color == "albino_pink":
		severity = 1.0
	elif eye_color == "pale_blue":
		severity = 0.6
	elif eye_color == "dark_blue" and skin_tone in ["albino_pale", "albino_light", "very_light"]:
		severity = 0.35
	
	var brightness : float = lerp(1.0, 1.6, severity)
	var alpha : float = lerp(1.0, 0.35, severity)
	var tint := Color(brightness, brightness, brightness, alpha)
	
	if lash_left:
		lash_left.modulate = tint
	if lash_right:
		lash_right.modulate = tint


func _tint(color: Color) -> Color:
	return color.darkened(TINT_DARKEN)


## Clear the face display
func clear() -> void:
	_current_phenotype = {}
	_cached_key = ""
	_setup_default_appearance()


## Get the current phenotype
func get_phenotype() -> Dictionary:
	return _current_phenotype
