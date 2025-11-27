class_name GenLayerClimateEdge
extends GenLayer

## Prevents incompatible climate zones from being adjacent
## Converts hot/cold boundaries to medium climate

# ============================================================================
# MODES
# ============================================================================

enum Mode {
	COOL_WARM,  # Prevents warm(1) from touching cold(3) - inserts medium(2)
	HEAT_ICE,   # Prevents warm(1) from touching frozen(4) - inserts cold(3)
}

# ============================================================================
# STATE
# ============================================================================

var mode: Mode

# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(p_base_seed: int, p_parent: GenLayer, p_mode: Mode) -> void:
	super._init(p_base_seed, p_parent)
	mode = p_mode

# ============================================================================
# GENERATION
# ============================================================================

func get_values(area_x: int, area_z: int, width: int, height: int) -> PackedInt32Array:
	# Fetch with 1-cell border
	var parent_width: int = width + 2
	var parent_height: int = height + 2
	var parent_values := parent.get_values(area_x - 1, area_z - 1, parent_width, parent_height)

	var result := PackedInt32Array()
	result.resize(width * height)

	for z in range(height):
		for x in range(width):
			init_chunk_seed(area_x + x, area_z + z)

			var center: int = parent_values[(x + 1) + (z + 1) * parent_width]
			var idx: int = x + z * width

			match mode:
				Mode.COOL_WARM:
					result[idx] = _process_cool_warm(parent_values, x, z, parent_width, center)
				Mode.HEAT_ICE:
					result[idx] = _process_heat_ice(parent_values, x, z, parent_width, center)

	return result


func _process_cool_warm(parent_values: PackedInt32Array, x: int, z: int, pw: int, center: int) -> int:
	# If warm(1), check if touching cold(3) or frozen(4)
	if center == 1:
		var north: int = parent_values[(x + 1) + z * pw]
		var south: int = parent_values[(x + 1) + (z + 2) * pw]
		var west: int = parent_values[x + (z + 1) * pw]
		var east: int = parent_values[(x + 2) + (z + 1) * pw]

		var touches_cold: bool = north == 3 or south == 3 or west == 3 or east == 3
		var touches_frozen: bool = north == 4 or south == 4 or west == 4 or east == 4

		if touches_cold or touches_frozen:
			return 2  # Convert to medium
	return center


func _process_heat_ice(parent_values: PackedInt32Array, x: int, z: int, pw: int, center: int) -> int:
	# If frozen(4), check if touching warm(1) or medium(2)
	if center == 4:
		var north: int = parent_values[(x + 1) + z * pw]
		var south: int = parent_values[(x + 1) + (z + 2) * pw]
		var west: int = parent_values[x + (z + 1) * pw]
		var east: int = parent_values[(x + 2) + (z + 1) * pw]

		var touches_warm: bool = north == 1 or south == 1 or west == 1 or east == 1
		var touches_medium: bool = north == 2 or south == 2 or west == 2 or east == 2

		if touches_warm or touches_medium:
			return 3  # Convert to cold
	return center
