class_name FoliagePlacer
extends RefCounted
## Foliage placement, receives shared grid from VegetationPlacer
## Same grid lookup as grass, plus: per-type eligibility + density

var rng: RandomNumberGenerator


func _init(p_rng: RandomNumberGenerator) -> void:
	rng = p_rng


func generate(chunk_pos: Vector2i, grid: Dictionary, lod_level: int = 0) -> Dictionary:
	var n_types: int = TerrainConfig.FOLIAGE_TYPES_PER_CHUNK
	var picked: PackedInt32Array = VegetationPlacerUtils.pick_variant_set(
		chunk_pos,
		TerrainConfig.FOLIAGE_TOTAL_TYPES,
		n_types,
		3,
	)

	var lod_candidates: Array[int] = TerrainConfig.FOLIAGE_LOD_CANDIDATES
	if lod_level >= lod_candidates.size() or lod_candidates[lod_level] == 0:
		var empty_transforms: Array[PackedFloat32Array] = []
		var empty_counts := PackedInt32Array()
		empty_transforms.resize(n_types)
		empty_counts.resize(n_types)
		for i in range(n_types):
			empty_transforms[i] = PackedFloat32Array()
			empty_counts[i] = 0
		return { "variant_ids": picked, "transforms": empty_transforms, "counts": empty_counts }

	var candidates: int = lod_candidates[lod_level]

	var grid_verts: PackedVector3Array = grid["verts"]
	var grid_colors: PackedColorArray = grid["colors"]
	var grid_res: int = grid["grid_res"]
	var grid_spacing: float = grid["grid_spacing"]
	var chunk_world_size: float = grid["chunk_world_size"]

	var transforms: Array[PackedFloat32Array] = []
	var counts := PackedInt32Array()
	transforms.resize(n_types)
	counts.resize(n_types)
	for i in range(n_types):
		transforms[i] = PackedFloat32Array()
		transforms[i].resize(candidates * 12)
		counts[i] = 0

	var grid_side: int = ceili(sqrt(float(candidates)))
	var cell_size: float = chunk_world_size / float(grid_side)
	var inv_grid_spacing: float = 1.0 / grid_spacing
	var max_gi: int = grid_res - 2
	var total_count: int = 0

	var foliage_densities: Array[float] = TerrainConfig.FOLIAGE_DENSITIES

	for gz in range(grid_side):
		for gx in range(grid_side):
			if total_count >= candidates:
				break

			var jx: float = rng.randf() * TerrainConfig.SAMPLE_JITTER
			var jz: float = rng.randf() * TerrainConfig.SAMPLE_JITTER
			var local_x: float = (float(gx) + jx) * cell_size
			var local_z: float = (float(gz) + jz) * cell_size

			# Same grid lookup as grass
			var gi: int = clampi(int(local_x * inv_grid_spacing), 0, max_gi)
			var gj: int = clampi(int(local_z * inv_grid_spacing), 0, max_gi)
			var grid_idx: int = gj * grid_res + gi

			var height: float = grid_verts[grid_idx].y
			if height < TerrainConfig.GRASS_MIN_HEIGHT or height >= TerrainConfig.HIGHLANDS_MIN:
				continue

			var h_right: float = grid_verts[grid_idx + 1].y
			var h_down: float = grid_verts[grid_idx + grid_res].y
			var dx: float = (h_right - height) * inv_grid_spacing
			var dz: float = (h_down - height) * inv_grid_spacing
			var normal_y: float = 1.0 / sqrt(dx * dx + dz * dz + 1.0)
			if normal_y < TerrainConfig.MIN_NORMAL_Y:
				continue

			var climate: Color = grid_colors[grid_idx]
			var temp_01: float = climate.r
			var moist_01: float = climate.g

			if temp_01 > TerrainConfig.DESERT_TEMP and moist_01 < TerrainConfig.DESERT_MOIST:
				continue

			# Per-type eligibility
			var eligible: PackedInt32Array = PackedInt32Array()
			for pi in range(n_types):
				if _is_eligible(picked[pi], temp_01, moist_01):
					eligible.append(pi)

			if eligible.is_empty():
				continue

			var chosen_pi: int = eligible[rng.randi() % eligible.size()]
			var chosen_type: int = picked[chosen_pi]

			if rng.randf() > foliage_densities[chosen_type]:
				continue

			# Foliage extras: moderate scale, no tilt
			var angle: float = rng.randf() * TAU
			var foliage_scale: float = rng.randf_range(0.8, 1.5)
			var c: int = counts[chosen_pi]
			VegetationPlacerUtils.write_transform(
				transforms[chosen_pi],
				c,
				local_x,
				height,
				local_z,
				foliage_scale,
				angle,
				TerrainConfig.FOLIAGE_Y_OFFSET,
			)
			counts[chosen_pi] = c + 1
			total_count += 1

	for i in range(n_types):
		transforms[i].resize(counts[i] * 12)

	return {
		"variant_ids": picked,
		"transforms": transforms,
		"counts": counts,
	}


static func _is_eligible(type_id: int, temp_01: float, moist_01: float) -> bool:
	match type_id:
		0:
			return true # Bush_Common
		1:
			return moist_01 > 0.45 # Bush_Common_Flowers
		2:
			return moist_01 > 0.5 # Fern_1
		3:
			return moist_01 > 0.55 and temp_01 >= 0.35 and temp_01 <= 0.7 # Mushroom_Common
		4:
			return moist_01 > 0.55 and temp_01 >= 0.35 and temp_01 <= 0.7 # Mushroom_Laetiporus
		5:
			return moist_01 > 0.3 # Flower_3_Group
		6:
			return true # Flower_3_Single
		7:
			return moist_01 > 0.35 # Flower_4_Group
		8:
			return true # Flower_4_Single
		9:
			return true # Plant_7
		10:
			return true # Plant_7_Big
		11:
			return true # Plant_1
		12:
			return moist_01 > 0.4 # Clover_1
		13:
			return moist_01 > 0.4 # Clover_2
	return false
