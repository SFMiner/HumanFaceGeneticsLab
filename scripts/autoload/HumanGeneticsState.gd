# HumanGeneticsState.gd
# Core genetics engine for the Human Face Genetics Simulator
# Manages gene library, phenotype calculations, human library, and breeding logic
# Educational purpose: Teach polygenic inheritance, epistasis, and complex trait expression

extends Node

# ============================================================================
# SIGNALS
# ============================================================================

signal human_added(human_id: int)
signal human_deleted(human_id: int)
signal human_updated(human_id: int)
signal breeding_complete(offspring_id: int)
signal level_changed(level_id: int)
signal library_loaded()

# ============================================================================
# CONSTANTS - GENE LIBRARY
# ============================================================================

## Complete gene library with all 8 genes
## Each gene has dominant/recessive alleles and affects specific traits
const GENE_LIBRARY: Dictionary = {
	"TYR": {
		"name": "Tyrosinase",
		"full_name": "Tyrosinase (Albinism Gene)",
		"dom": "A",
		"rec": "a",
		"description": "Master switch for melanin production. 'aa' results in oculocutaneous albinism (OCA1).",
		"affects": ["eye_color", "skin_tone", "hair_color"],
		"epistatic": true,
		"epistatic_condition": "aa",
		"epistatic_result": {"eye_color": "albino_pink", "skin_tone": "albino_pale", "hair_color": "albino_white"}
	},
	"ALB": {
		"name": "Albinism Locus",
		"full_name": "Albinism Locus (Pigment Suppression)",
		"dom": "N",
		"rec": "n",
		"description": "Controls albinism expression. Recessive nn triggers albinism effects with TYR-dependent severity.",
		"affects": ["eye_color", "skin_tone", "hair_color"],
		"epistatic": true
	},
	"OCA2": {
		"name": "OCA2",
		"full_name": "P-Protein (Brown Eye Gene)",
		"dom": "B",
		"rec": "b",
		"description": "Primary determinant of brown vs. blue/green eyes. Also contributes to skin pigmentation.",
		"affects": ["eye_color", "skin_tone"],
		"epistatic": false
	},
	"HERC2": {
		"name": "HERC2",
		"full_name": "HERC2 Regulator (Green Modifier)",
		"dom": "G",
		"rec": "g",
		"description": "Regulates OCA2 expression. Determines green vs. blue when brown is absent.",
		"affects": ["eye_color"],
		"epistatic": false
	},
	"TYRP1": {
		"name": "TYRP1",
		"full_name": "Tyrosinase-Related Protein 1",
		"dom": "H",
		"rec": "h",
		"description": "Affects eumelanin intensity in eyes and hair. Creates brown vs. blonde spectrum.",
		"affects": ["eye_color", "hair_color"],
		"epistatic": false
	},
	"SLC24A5": {
		"name": "SLC24A5",
		"full_name": "Solute Carrier 24A5 (Skin Lightening)",
		"dom": "D",
		"rec": "d",
		"description": "Major skin pigmentation gene. One of the strongest lightening factors.",
		"affects": ["skin_tone", "eye_color"],
		"epistatic": false
	},
	"SLC45A2": {
		"name": "SLC45A2",
		"full_name": "Solute Carrier 45A2 (Secondary Skin Tone)",
		"dom": "E",
		"rec": "e",
		"description": "Secondary skin lightening gene. Works additively with SLC24A5.",
		"affects": ["skin_tone"],
		"epistatic": false
	},
	"MC1R": {
		"name": "MC1R",
		"full_name": "Melanocortin 1 Receptor (Red Hair Gene)",
		"dom": "R",
		"rec": "r",
		"description": "Controls pheomelanin (red pigment) production. RR = bright red, Rr = auburn, rr = normal. Also causes freckles.",
		"affects": ["hair_color", "skin_tone"],
		"epistatic": false,
		"special_dominance": "incomplete"
	},
	"TCHH": {
		"name": "TCHH",
		"full_name": "Trichohyalin (Hair Texture)",
		"dom": "C",
		"rec": "c",
		"description": "Determines hair shaft shape. CC = straight, Cc = wavy, cc = curly.",
		"affects": ["hair_texture"],
		"epistatic": false,
		"special_dominance": "incomplete"
	}
}

## Convenience genotypes for backward compatibility when loading humans
## from earlier levels into later levels (heterozygous for maximum variation)
const CONVENIENCE_GENOTYPES: Dictionary = {
	"TYR": ["A", "a"],
	"ALB": ["N", "n"],
	"OCA2": ["B", "b"],
	"HERC2": ["G", "g"],
	"TYRP1": ["H", "h"],
	"SLC24A5": ["D", "d"],
	"SLC45A2": ["E", "e"],
	"MC1R": ["r", "r"],
	"TCHH": ["C", "c"]
}

## Neutral genotypes for inactive genes (minimize unintended trait influence)
const NEUTRAL_GENOTYPES: Dictionary = {
	"TYR": ["A", "A"],
	"ALB": ["N", "N"],
	"OCA2": ["b", "b"],
	"HERC2": ["g", "g"],
	"TYRP1": ["h", "h"],
	"SLC24A5": ["d", "d"],
	"SLC45A2": ["e", "e"],
	"MC1R": ["r", "r"],
	"TCHH": ["C", "C"]
}

## Phenotype color palettes
const EYE_COLOR_PALETTE: Dictionary = {
	"albino_pink": Color("#FFB6C1"),
	"pale_blue": Color("#B8D4F4"),
	"dark_brown": Color("#3E2723"),
	"medium_brown": Color("#634E34"),
	"light_brown": Color("#8B6F47"),
	"hazel": Color("#73682A"),
	"dark_green": Color("#2E5C1E"),
	"light_green": Color("#6B8E23"),
	"dark_blue": Color("#1A3B5C"),
	"light_blue": Color("#5B9BD5")
}

const SKIN_TONE_PALETTE: Dictionary = {
	"albino_pale": Color("#FFF5F5"),
	"albino_light": Color("#FFF0DD"),
	"very_light": Color("#FFDFC4"),
	"very_light_freckled": Color("#FFDFC4"),
	"light": Color("#F0C8A0"),
	"light_freckled": Color("#F0C8A0"),
	"medium": Color("#C68642"),
	"dark": Color("#8D5524"),
	"very_dark": Color("#4A2511")
}

const HAIR_COLOR_PALETTE: Dictionary = {
	"albino_white": Color("#FFFFFF"),
	"platinum_blonde": Color("#F6EEDC"),
	"bright_red": Color("#C1440E"),
	"auburn": Color("#A0522D"),
	"black": Color("#1C1C1C"),
	"dark_brown": Color("#3B2414"),
	"medium_brown": Color("#6F4E37"),
	"light_brown": Color("#B5864F"),
	"blonde": Color("#F4E4C1")
}

# ============================================================================
# STATE VARIABLES
# ============================================================================

## Human library (all created/saved humans)
var humans: Dictionary = {}  # id -> human_data
var next_id: int = 1
var favorites: Array[int] = []
var tags: Dictionary = {}  # id -> Array[String]

## Level configuration
var levels_config: Array = []
var current_level_id: int = 1
var current_level_data: Dictionary = {}

## Names for random generation
var first_names: Array = []
var last_names: Array = []

## Random number generator (can be seeded for deterministic mode)
var rng: RandomNumberGenerator = RandomNumberGenerator.new()

# ============================================================================
# LIFECYCLE
# ============================================================================

func _ready() -> void:
	rng.randomize()
	_load_levels_config()
	_load_names()
	load_library()
	set_level(1)


# ============================================================================
# LEVEL MANAGEMENT
# ============================================================================

## Load levels configuration from JSON
func _load_levels_config() -> void:
	var file := FileAccess.open("res://data/levels.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			levels_config = json.data.get("levels", [])
		else:
			push_error("Failed to parse levels.json")
	else:
		push_error("Could not open levels.json")


## Load names for random generation
func _load_names() -> void:
	var file := FileAccess.open("res://data/names.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		if error == OK and json.data is Dictionary:
			first_names = json.data.get("first_names", [])
			last_names = json.data.get("last_names", [])


## Set the current level
func set_level(level_id: int) -> void:
	for level in levels_config:
		if level.get("id") == level_id:
			current_level_id = level_id
			current_level_data = level
			level_changed.emit(level_id)
			return
	push_warning("Level %d not found" % level_id)


## Get active genes for current level
func get_active_genes() -> Array:
	return current_level_data.get("active_genes", ["TYR", "OCA2", "HERC2"])


## Get traits displayed for current level
func get_traits_displayed() -> Array:
	return current_level_data.get("traits_displayed", ["eye_color"])


## Get max punnett genes for current level
func get_max_punnett_genes() -> int:
	return current_level_data.get("max_punnett_genes", 2)


## Get all available levels
func get_all_levels() -> Array:
	return levels_config


## Get current level data
func get_current_level() -> Dictionary:
	return current_level_data


## Check if albinism is allowed for the current level
func is_albinism_allowed() -> bool:
	return current_level_data.get("allow_albinism", true)


# ============================================================================
# PHENOTYPE CALCULATIONS
# ============================================================================

## Calculate complete phenotype from genotype
func calculate_phenotype(genotype: Dictionary) -> Dictionary:
	var phenotype: Dictionary = {}
	phenotype["eye_color"] = calculate_eye_color(genotype)
	phenotype["skin_tone"] = calculate_skin_tone(genotype)
	phenotype["hair_color"] = calculate_hair_color(genotype)
	phenotype["hair_texture"] = calculate_hair_texture(genotype)
	return phenotype


## Calculate eye color from genotype
## Implements epistasis (TYR) and polygenic inheritance (OCA2, HERC2, TYRP1, SLC24A5)
func calculate_eye_color(genotype: Dictionary) -> String:
	var active_genes := get_active_genes()
	var tyr: Array = _get_tyrosinase_pair_for_level(genotype, active_genes)
	var alb: Array = _get_albinism_pair_for_level(genotype, active_genes)
	if alb.count("n") == 2:
		# Albinism severity is modulated by TYR dosage.
		if not "A" in tyr:
			return "albino_pink"
		if tyr.count("A") == 1:
			return "pale_blue"
		return "dark_blue"
	
	# POLYGENIC CALCULATION
	var oca2: Array = _get_gene_pair_for_level(genotype, "OCA2", active_genes)
	var herc2: Array = _get_gene_pair_for_level(genotype, "HERC2", active_genes)
	var tyrp1: Array = _get_gene_pair_for_level(genotype, "TYRP1", active_genes)
	var slc24a5: Array = _get_gene_pair_for_level(genotype, "SLC24A5", active_genes)
	
	# Brown pathway (OCA2 dominant)
	if "B" in oca2:
		if oca2.count("B") == 2 and "H" in tyrp1:
			return "dark_brown"  # BB + H_ = darkest
		elif oca2.count("B") == 2:
			return "medium_brown"  # BB + hh
		elif "H" in tyrp1:
			return "light_brown"  # Bb + H_
		else:
			return "hazel"  # Bb + hh
	
	# Non-brown pathway (oca2 = bb)
	else:
		if "G" in herc2:
			# Green pathway
			if herc2.count("G") == 2:
				return "dark_green"  # GG
			else:
				return "light_green"  # Gg
		else:
			# Blue pathway (affected by lightening genes)
			if "D" in slc24a5 or tyrp1.count("H") > 0:
				return "light_blue"  # Lightening factors present
			else:
				return "dark_blue"  # Fully recessive
	
	return "medium_brown"  # Fallback


## Calculate skin tone from genotype
## Implements additive model with freckle modifier
func calculate_skin_tone(genotype: Dictionary) -> String:
	var active_genes := get_active_genes()
	var tyr: Array = _get_tyrosinase_pair_for_level(genotype, active_genes)
	var alb: Array = _get_albinism_pair_for_level(genotype, active_genes)
	if alb.count("n") == 2:
		# TYR aa yields full albinism; TYR Aa gives partial depigmentation.
		if not "A" in tyr:
			return "albino_pale"
		if tyr.count("A") == 1:
			return "albino_light"
		return "very_light"
	
	# POLYGENIC CALCULATION (additive model)
	var darkness_score: int = 0
	
	var slc24a5: Array = _get_gene_pair_for_level(genotype, "SLC24A5", active_genes)
	var slc45a2: Array = _get_gene_pair_for_level(genotype, "SLC45A2", active_genes)
	var oca2: Array = _get_gene_pair_for_level(genotype, "OCA2", active_genes)
	var mc1r: Array = _get_gene_pair_for_level(genotype, "MC1R", active_genes)
	
	# Each dominant allele adds to darkness
	darkness_score += slc24a5.count("D") * 2  # Major effect (0-4 points)
	darkness_score += slc45a2.count("E") * 2  # Major effect (0-4 points)
	darkness_score += oca2.count("B")         # Minor effect (0-2 points)
	
	# MC1R modifier (freckles)
	var has_freckles: bool = "R" in mc1r
	
	# Map score to phenotype (0-10 scale)
	var base_tone: String = ""
	if darkness_score >= 9:
		base_tone = "very_dark"
	elif darkness_score >= 7:
		base_tone = "dark"
	elif darkness_score >= 5:
		base_tone = "medium"
	elif darkness_score >= 3:
		base_tone = "light"
	else:
		base_tone = "very_light"
	
	# Append freckle modifier (only on lighter skin)
	if has_freckles and base_tone in ["light", "very_light"]:
		return base_tone + "_freckled"
	else:
		return base_tone


## Calculate hair color from genotype
## Implements MC1R epistasis for red hair
func calculate_hair_color(genotype: Dictionary) -> String:
	var active_genes := get_active_genes()
	var tyr: Array = _get_tyrosinase_pair_for_level(genotype, active_genes)
	var alb: Array = _get_albinism_pair_for_level(genotype, active_genes)
	if alb.count("n") == 2:
		# Albinism lightens hair color with TYR-dependent severity.
		if not "A" in tyr:
			return "albino_white"
		if tyr.count("A") == 1:
			return "platinum_blonde"
		var base_hair := _calculate_hair_color_base(genotype, active_genes)
		if base_hair in ["blonde", "light_brown"]:
			return base_hair
		return "light_brown"
	
	return _calculate_hair_color_base(genotype, active_genes)


## Calculate hair texture from genotype
## Implements incomplete dominance (3 distinct phenotypes)
func calculate_hair_texture(genotype: Dictionary) -> String:
	var active_genes := get_active_genes()
	var tchh: Array = _get_gene_pair_for_level(genotype, "TCHH", active_genes)
	
	# Incomplete dominance - 3 distinct phenotypes
	if tchh.count("C") == 2:
		return "straight"
	elif "C" in tchh and "c" in tchh:
		return "wavy"
	else:
		return "curly"


## Base hair color calculation without albinism effects
func _calculate_hair_color_base(genotype: Dictionary, active_genes: Array) -> String:
	# MC1R EPISTASIS (red hair pathway) - incomplete dominance
	var mc1r: Array = _get_gene_pair_for_level(genotype, "MC1R", active_genes)
	if mc1r.count("R") == 2:
		return "bright_red"  # Homozygous RR
	elif "R" in mc1r:
		return "auburn"  # Heterozygous Rr
	
	# EUMELANIN PATHWAY (TYRP1 + OCA2)
	var tyrp1: Array = _get_gene_pair_for_level(genotype, "TYRP1", active_genes)
	var oca2: Array = _get_gene_pair_for_level(genotype, "OCA2", active_genes)
	
	var darkness_score: int = tyrp1.count("H") * 2 + oca2.count("B")
	
	if darkness_score >= 4:
		return "black"
	elif darkness_score == 3:
		return "dark_brown"
	elif darkness_score == 2:
		return "medium_brown"
	elif darkness_score == 1:
		return "light_brown"
	else:
		return "blonde"


# ============================================================================
# COLOR GETTERS
# ============================================================================

## Get the color for an eye color phenotype
func get_eye_color(phenotype_name: String) -> Color:
	return EYE_COLOR_PALETTE.get(phenotype_name, Color.GRAY)


## Get the color for a skin tone phenotype
func get_skin_color(phenotype_name: String) -> Color:
	# Remove freckled suffix for color lookup
	var base_name := phenotype_name.replace("_freckled", "")
	return SKIN_TONE_PALETTE.get(base_name, Color.GRAY)


## Get the color for a hair color phenotype
func get_hair_color(phenotype_name: String) -> Color:
	return HAIR_COLOR_PALETTE.get(phenotype_name, Color.GRAY)


## Check if a skin tone has freckles
func has_freckles(skin_tone: String) -> bool:
	return skin_tone.ends_with("_freckled")


# ============================================================================
# HUMAN MANAGEMENT
# ============================================================================

## Add a new human to the library
func add_human(genotype: Dictionary, human_name: String = "", generation: int = 0, parent_a_id: int = -1, parent_b_id: int = -1) -> int:
	var normalized := normalize_genotype(genotype)
	var phenotype := calculate_phenotype(normalized)
	
	var final_name := human_name
	if final_name.is_empty():
		final_name = generate_random_name()
	
	var human_data: Dictionary = {
		"id": next_id,
		"name": final_name,
		"genotype": normalized,
		"phenotype": phenotype,
		"generation": generation,
		"parent_a_id": parent_a_id,
		"parent_b_id": parent_b_id,
		"created_at": Time.get_unix_time_from_system()
	}
	
	humans[next_id] = human_data
	var added_id := next_id
	next_id += 1
	
	human_added.emit(added_id)
	save_library()
	return added_id


## Get a human by ID
func get_human(id: int) -> Dictionary:
	return humans.get(id, {})


## Get all humans
func get_all_humans() -> Array:
	return humans.values()


## Delete a human from the library
func delete_human(id: int) -> void:
	if humans.has(id):
		humans.erase(id)
		if id in favorites:
			favorites.erase(id)
		if tags.has(id):
			tags.erase(id)
		human_deleted.emit(id)
		save_library()


## Update a human's name
func update_human_name(id: int, new_name: String) -> void:
	if humans.has(id):
		humans[id]["name"] = new_name
		human_updated.emit(id)
		save_library()


## Toggle favorite status
func toggle_favorite(id: int) -> bool:
	if id in favorites:
		favorites.erase(id)
		save_library()
		return false
	else:
		favorites.append(id)
		save_library()
		return true


## Check if a human is favorited
func is_favorite(id: int) -> bool:
	return id in favorites


# ============================================================================
# GENOTYPE UTILITIES
# ============================================================================

## Normalize a genotype to ensure all genes have proper format
func normalize_genotype(genotype: Dictionary) -> Dictionary:
	var normalized: Dictionary = {}
	for gene_id in GENE_LIBRARY.keys():
		if genotype.has(gene_id):
			var alleles: Array = genotype[gene_id]
			if alleles.size() >= 2:
				normalized[gene_id] = [alleles[0], alleles[1]]
			else:
				normalized[gene_id] = CONVENIENCE_GENOTYPES[gene_id].duplicate()
		else:
			normalized[gene_id] = CONVENIENCE_GENOTYPES[gene_id].duplicate()
	return normalized


## Apply convenience genotypes for missing genes
func apply_convenience_genotypes(genotype: Dictionary) -> Dictionary:
	var result := genotype.duplicate(true)
	for gene_id in GENE_LIBRARY.keys():
		if not result.has(gene_id):
			result[gene_id] = CONVENIENCE_GENOTYPES[gene_id].duplicate()
	return result


## Generate a random genotype for the current level
func generate_random_genotype() -> Dictionary:
	var genotype: Dictionary = {}
	var active_genes := get_active_genes()
	
	for gene_id in GENE_LIBRARY.keys():
		if gene_id in active_genes:
			# Randomize active genes
			genotype[gene_id] = _generate_random_allele_pair(gene_id)
		else:
			# Use convenience genotypes for inactive genes
			genotype[gene_id] = CONVENIENCE_GENOTYPES[gene_id].duplicate()
	
	return genotype


## Generate a random allele pair for a gene
func _generate_random_allele_pair(gene_id: String) -> Array:
	var gene_data: Dictionary = GENE_LIBRARY.get(gene_id, {})
	var dom: String = gene_data.get("dom", "A")
	var rec: String = gene_data.get("rec", "a")
	
	# Special handling for skin genes at level 3+ (weighted distribution)
	if gene_id in ["SLC24A5", "SLC45A2"] and current_level_id >= 3:
		var roll := rng.randf()
		if roll < 0.2:
			return [dom, dom]  # 20% homozygous dominant
		elif roll < 0.7:
			return [dom, rec]  # 50% heterozygous
		else:
			return [rec, rec]  # 30% homozygous recessive
	
	# Standard random distribution
	var allele1: String = dom if rng.randf() < 0.5 else rec
	var allele2: String = dom if rng.randf() < 0.5 else rec
	return [allele1, allele2]


## Generate a random human with random genotype
func generate_random_human() -> int:
	var genotype := generate_random_genotype()
	return add_human(genotype, "", 0)


## Get a gene pair that respects current level activity
func _get_gene_pair_for_level(genotype: Dictionary, gene_id: String, active_genes: Array) -> Array:
	if gene_id in active_genes:
		return genotype.get(gene_id, CONVENIENCE_GENOTYPES.get(gene_id, ["A", "a"]))
	# Inactive genes default to neutralized alleles to avoid unintended effects.
	return NEUTRAL_GENOTYPES.get(gene_id, CONVENIENCE_GENOTYPES.get(gene_id, ["A", "a"]))


## Get ALB pair with optional albinism constraints
func _get_albinism_pair_for_level(genotype: Dictionary, active_genes: Array) -> Array:
	if not is_albinism_allowed():
		# Clamp ALB to NN when albinism is disabled for the level.
		return ["N", "N"]
	return _get_gene_pair_for_level(genotype, "ALB", active_genes)


## Get TYR pair with optional albinism constraints
func _get_tyrosinase_pair_for_level(genotype: Dictionary, active_genes: Array) -> Array:
	var tyr: Array = _get_gene_pair_for_level(genotype, "TYR", active_genes)
	return tyr


## Sanitize a genotype to respect current level constraints
func sanitize_genotype_for_level(genotype: Dictionary) -> Dictionary:
	var result := genotype.duplicate(true)
	return result


# ============================================================================
# BREEDING / RECOMBINATION
# ============================================================================

## Breed two parents to create an offspring
## Returns the new human's ID, or -1 on failure
func breed(parent_a_id: int, parent_b_id: int, selected_cell: int = -1) -> int:
	var parent_a := get_human(parent_a_id)
	var parent_b := get_human(parent_b_id)
	
	if parent_a.is_empty() or parent_b.is_empty():
		push_error("Invalid parent IDs for breeding")
		return -1
	
	# Check Teacher Mode constraints
	if TeacherModeState.is_active():
		if not TeacherModeState.can_breed(parent_a_id, parent_b_id):
			push_warning("Breeding blocked by Teacher Mode")
			return -1
	
	# Build Punnett square and select offspring genotype
	var active_genes := get_active_genes()
	var punnett := build_punnett_square(parent_a_id, parent_b_id, active_genes)
	
	if punnett.is_empty():
		push_error("Failed to build Punnett square")
		return -1
	
	# Select cell (random or specified)
	var cell_index: int
	if selected_cell >= 0 and selected_cell < punnett.size():
		cell_index = selected_cell
	elif TeacherModeState.is_active() and TeacherModeState.is_deterministic():
		# Use seeded random
		cell_index = TeacherModeState.get_seeded_random_int(0, punnett.size() - 1)
	else:
		cell_index = rng.randi_range(0, punnett.size() - 1)
	
	var offspring_genotype: Dictionary = punnett[cell_index]
	offspring_genotype = sanitize_genotype_for_level(offspring_genotype)
	offspring_genotype = sanitize_genotype_for_level(offspring_genotype)
	
	# Determine generation
	var parent_a_gen: int = parent_a.get("generation", 0)
	var parent_b_gen: int = parent_b.get("generation", 0)
	var offspring_gen: int = max(parent_a_gen, parent_b_gen) + 1
	
	# Create offspring
	var offspring_id := add_human(offspring_genotype, "", offspring_gen, parent_a_id, parent_b_id)
	breeding_complete.emit(offspring_id)
	return offspring_id


## Build a Punnett square for given parents and genes
## Returns an array of all possible offspring genotypes
func build_punnett_square(parent_a_id: int, parent_b_id: int, gene_ids: Array) -> Array:
	var parent_a := get_human(parent_a_id)
	var parent_b := get_human(parent_b_id)
	
	if parent_a.is_empty() or parent_b.is_empty():
		return []
	
	var genotype_a: Dictionary = parent_a.get("genotype", {})
	var genotype_b: Dictionary = parent_b.get("genotype", {})
	
	# Build gametes for each parent
	var gametes_a := build_gametes(genotype_a, gene_ids)
	var gametes_b := build_gametes(genotype_b, gene_ids)
	
	# Combine gametes to create all possible offspring
	var punnett: Array = []
	for gamete_a in gametes_a:
		for gamete_b in gametes_b:
			var offspring_genotype := _combine_gametes(gamete_a, gamete_b)
			# Apply convenience genotypes for inactive genes
			offspring_genotype = apply_convenience_genotypes(offspring_genotype)
			punnett.append(offspring_genotype)
	
	return punnett


## Build all possible gametes from a genotype for given genes
## Uses independent assortment
func build_gametes(genotype: Dictionary, gene_ids: Array) -> Array:
	if gene_ids.is_empty():
		return [{}]
	
	# Start with first gene
	var first_gene: String = gene_ids[0]
	var alleles: Array = genotype.get(first_gene, CONVENIENCE_GENOTYPES.get(first_gene, ["A", "a"]))
	
	# Get gametes for remaining genes recursively
	var remaining_genes: Array = gene_ids.slice(1)
	var sub_gametes := build_gametes(genotype, remaining_genes)
	
	# Combine with current gene's alleles
	var result: Array = []
	for allele in alleles:
		for sub_gamete in sub_gametes:
			var new_gamete: Dictionary = sub_gamete.duplicate()
			new_gamete[first_gene] = allele
			result.append(new_gamete)
	
	return result


## Combine two gametes into a diploid genotype
func _combine_gametes(gamete_a: Dictionary, gamete_b: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	var all_genes := gamete_a.keys()
	for gene in gamete_b.keys():
		if gene not in all_genes:
			all_genes.append(gene)
	
	for gene_id in all_genes:
		var allele_a: String = gamete_a.get(gene_id, "")
		var allele_b: String = gamete_b.get(gene_id, "")
		if allele_a.is_empty():
			allele_a = CONVENIENCE_GENOTYPES.get(gene_id, ["A", "a"])[0]
		if allele_b.is_empty():
			allele_b = CONVENIENCE_GENOTYPES.get(gene_id, ["A", "a"])[1]
		result[gene_id] = [allele_a, allele_b]
	
	return result


# ============================================================================
# NAME GENERATION
# ============================================================================

## Generate a random name
func generate_random_name() -> String:
	if first_names.is_empty() or last_names.is_empty():
		return "Human %03d" % next_id
	
	var first: String = first_names[rng.randi_range(0, first_names.size() - 1)]
	var last: String = last_names[rng.randi_range(0, last_names.size() - 1)]
	return "%s %s" % [first, last]


# ============================================================================
# PERSISTENCE
# ============================================================================

## Save the library to user data
func save_library() -> void:
	var data: Dictionary = {
		"humans": humans,
		"next_id": next_id,
		"favorites": favorites,
		"tags": tags
	}
	
	var file := FileAccess.open("user://human_library.json", FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data, "\t"))
		file.close()
	else:
		push_error("Failed to save library")


## Load the library from user data
func load_library() -> void:
	if not FileAccess.file_exists("user://human_library.json"):
		# No saved library, create starter humans
		_create_starter_humans()
		library_loaded.emit()
		return
	
	var file := FileAccess.open("user://human_library.json", FileAccess.READ)
	if file:
		var json := JSON.new()
		var error := json.parse(file.get_as_text())
		file.close()
		
		if error == OK and json.data is Dictionary:
			var data: Dictionary = json.data
			
			# Restore humans (convert string keys to int)
			humans.clear()
			var loaded_humans: Dictionary = data.get("humans", {})
			for key in loaded_humans.keys():
				var int_key: int = int(key)
				humans[int_key] = loaded_humans[key]
			
			next_id = data.get("next_id", 1)
			
			# Restore favorites
			favorites.clear()
			for fav in data.get("favorites", []):
				favorites.append(int(fav))
			
			# Restore tags
			tags.clear()
			var loaded_tags: Dictionary = data.get("tags", {})
			for key in loaded_tags.keys():
				tags[int(key)] = loaded_tags[key]
			
			library_loaded.emit()
		else:
			push_error("Failed to parse library file")
			_create_starter_humans()
			library_loaded.emit()
	else:
		push_error("Failed to open library file")
		_create_starter_humans()
		library_loaded.emit()


## Create starter humans from current level config
func _create_starter_humans() -> void:
	var starters: Array = current_level_data.get("starter_humans", [])
	for starter in starters:
		var genotype: Dictionary = starter.get("genotype", {})
		var name: String = starter.get("name", "")
		add_human(genotype, name, 0)


## Clear the library (for session reset)
func clear_library() -> void:
	humans.clear()
	next_id = 1
	favorites.clear()
	tags.clear()
	save_library()


# ============================================================================
# GENE INFO HELPERS
# ============================================================================

## Get description for a gene
func get_gene_description(gene_id: String) -> String:
	var gene_data: Dictionary = GENE_LIBRARY.get(gene_id, {})
	return gene_data.get("description", "Unknown gene")

## Get full gene info dictionary
func get_gene_info(gene_id: String) -> Dictionary:
	if GENE_LIBRARY.has(gene_id):
		return GENE_LIBRARY[gene_id]
	return {}
	
## Get full name for a gene
func get_gene_full_name(gene_id: String) -> String:
	var gene_data: Dictionary = GENE_LIBRARY.get(gene_id, {})
	return gene_data.get("full_name", gene_id)


## Get all possible allele pairs for a gene
func get_allele_pairs(gene_id: String) -> Array:
	var gene_data: Dictionary = GENE_LIBRARY.get(gene_id, {})
	var dom: String = gene_data.get("dom", "A")
	var rec: String = gene_data.get("rec", "a")
	return [
		[dom, dom],
		[dom, rec],
		[rec, rec]
	]


## Format allele pair for display (e.g., "Aa")
func format_allele_pair(alleles: Array) -> String:
	if alleles.size() < 2:
		return "??"
	return alleles[0] + alleles[1]


## Check if an allele is dominant
func is_dominant_allele(allele: String) -> bool:
	return allele == allele.to_upper()
