class_name RiverGenerator
extends RefCounted 

var terrain: TerrainGenerator

func _init(p_terrain:TerrainGenerator) -> void:
	terrain = p_terrain
	
func is_best_among_neighboors(candidate: Vector3, sources_candidates : Array[Vector3]) -> bool:#
	# Check among the candidates the neighboors first
	# Then check which one is the best possible cnadidate with the following criterias:
	#	 - in a steep slop (not for now but #TODO)
	#	 - highest point among them... 

	# check if is in neighboors
	var neighboors_radius := 300.0
	
	for source in sources_candidates:
		# checking if near the candidate
		if candidate.distance_to(source) <= neighboors_radius:
			if -terrain.get_gradient(candidate.x, candidate.z) <-terrain.get_gradient(source.x, source.z):
				return false
	return true
	
func find_source(center: Vector2, area_size: float) -> Array[Vector3]:
	var step := 80.0
	var half := area_size / 2.0
	var sources_candidates : Array[Vector3] = []
	var grid_count_x := int(area_size / step)
	var grid_count_z := int(area_size / step)
	
	# finding possible sources
	for gx in range(grid_count_x):
		for gz in range(grid_count_z):
			var x := center.x - half + gx * step
			var z := center.y - half + gz * step
			var h := terrain.get_height(x, z)
			if h >= 180.0:
				sources_candidates.append(Vector3(x, h, z))
	
	# selecting randomly sources
	var sources: Array[Vector3] = []
	for candidate in sources_candidates:
		if is_best_among_neighboors(candidate, sources_candidates):
			sources.append(candidate)
		
	return sources
	
func build_river_controls_points(source:Vector3) -> PackedVector3Array:
	var pos := Vector2(source.x, source.z)
	var max_steps := 500
	var step_dist := 25.0
	
	var path : PackedVector3Array = []
	
	for i in range(max_steps):
		path.append(Vector3(pos.x, terrain.get_height(pos.x, pos.y), pos.y))
		
		var gradient := terrain.get_gradient(pos.x, pos.y)
		var slope := -gradient
		var slope_dir := slope.normalized()
		
		if slope.length() <= 0.01:
			break
		
		pos += slope_dir * step_dist
		
	return path
