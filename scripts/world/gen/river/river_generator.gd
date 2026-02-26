class_name RiverGenerator
extends RefCounted 

var terrain: TerrainGenerator
var terrain_cache: Dictionary[Vector2, Vector2] = {}
var coast_cells_cache: Dictionary[Vector2, PackedVector2Array] = {}
var flat_cells_cache: Dictionary[Vector2, PackedVector2Array] = {}

func _init(p_terrain: TerrainGenerator) -> void:
	terrain = p_terrain
	terrain_cache = {}
	coast_cells_cache = {}
	flat_cells_cache = {}
	
func is_best_among_neighboors(candidate: Vector3, sources_candidates : Array[Vector3]) -> bool:#
	# Check among the candidates the neighboors first
	# Then check which one is the best possible cnadidate with the following criterias:
	#	 - in a steep slop (not for now but #TODO)
	#	 - highest point among them... 

	# check if is in neighboors
	var neighboors_radius := 150.0
	
	for source in sources_candidates:
		# checking if near the candidate
		if candidate.distance_to(source) <= neighboors_radius:
			if -terrain.get_gradient(candidate.x, candidate.z) < \
			   -terrain.get_gradient(source.x, source.z):
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
			if h >= 130.0:
				sources_candidates.append(Vector3(x, h, z))
	
	# selecting randomly sources
	var sources: Array[Vector3] = []
	for candidate in sources_candidates:
		if is_best_among_neighboors(candidate, sources_candidates):
			sources.append(candidate)
		
	return sources
	
func build_river_controls_points(source:Vector3) -> PackedVector3Array:
	var pos := Vector2(source.x, source.z)
	var max_steps := 200
	var step_dist := 16.0
	
	var path : PackedVector3Array = []
	
	for i in range(max_steps):
		path.append(Vector3(pos.x, terrain.get_height(pos.x, pos.y), pos.y))
		
		var gradient := terrain.get_gradient(pos.x, pos.y)
		var slope := -gradient
		var slope_dir := slope.normalized()
		
		if slope.length() <= 1e-5:
			break
		
		pos += slope_dir * step_dist
		
	return path

func _cached_cell(pos: Vector2) -> Vector2:
	# Cache hit :-)
	if terrain_cache.has(pos):
		return terrain_cache[pos]
	
	# Cache miss :-(
	var height := terrain.get_height(pos.x, pos.y)
	var grad := -terrain.get_gradient(pos.x, pos.y)
	var slope_mag := grad.length() 

	var sample := Vector2(height, slope_mag)
	terrain_cache[pos] = sample
	return sample

func load_grid(center: Vector2, area_size: int) -> void:
	# Init a low res terrain grid, step is 1/3 of a chunk.
	# Detect flat cell and coast cell and store fetched value
	# in a cache. Each flat cells are set with union-find to detect
	# if cell are connected to a coast cell.
	
	var step := 64.0
	var sea_level = 0.0
	var mountains_level = 130.0
	
	# TODO check the tresholds values...
	var slope_threshold := step/8.0
	var delta_height_threshold := step/2.0

	var half := float(area_size) * 0.5
	var origin := center - Vector2(half, half)

	var cells_x := int(floor(float(area_size) / step))
	var cells_z := int(floor(float(area_size) / step))

	var coast_cells := PackedVector2Array()
	var flat_cells := PackedVector2Array()

	for gx in range(cells_x):
		for gz in range(cells_z):
			var x0 := origin.x + gx * step
			var z0 := origin.y + gz * step

			# Cell corners
			var bl := Vector2(x0, z0)               # BL
			var br := Vector2(x0 + step, z0)        # BR
			var ul := Vector2(x0, z0 + step)        # UL
			var ur := Vector2(x0 + step, z0 + step) # UR

			# Cell center
			var cc := Vector2(x0 + step * 0.5, z0 + step * 0.5)
			
			# V for vector ...
			var v_bl := _cached_cell(bl)
			var v_br := _cached_cell(br)
			var v_ul := _cached_cell(ul)
			var v_ur := _cached_cell(ur)
			var v_cc  := _cached_cell(cc)

			# Heights
			var hbl := v_bl.x
			var hbr := v_br.x
			var hul := v_ul.x
			var hur := v_ur.x
			var hcc := v_cc.x

			var sbl := v_bl.y
			var sbr := v_br.y
			var sul := v_ul.y
			var sur := v_ur.y
			var scc := v_cc.y
			
			var min_h = min(min(hbl, hbr), min(min(hul, hur), hcc))
			var max_h = max(max(hbl, hbr), max(max(hul, hur), hcc))
			if hcc > 0.0 and min_h <= 0.0 and max_h >= 0.0:
				coast_cells.append(cc)

			var average_slope := (sbl + sbr + sul + sur + scc) / 5.0
			var delta_height = max_h - min_h

			if hcc > sea_level and hcc <= mountains_level \
			and average_slope <= slope_threshold \
			and delta_height <= delta_height_threshold:
				flat_cells.append(cc)

	coast_cells_cache[center] = coast_cells
	flat_cells_cache[center] = flat_cells
	
func build_groups_bfs(center: Vector2) -> Array[Dictionary]:
	var step := 64.0
	var flat_cells := flat_cells_cache[center]
	var coast_cells := coast_cells_cache[center]

	# Set for more perfomance fetching...
	var flat_set: Dictionary = {}
	for cell in flat_cells:
		flat_set[cell] = true

	var coast_set: Dictionary = {}
	for cell in coast_cells:
		coast_set[cell] = true

	var visited: Dictionary = {}
	var groups: Array[Dictionary] = []
	var cell_to_group: Dictionary = {}

	# 4-connected positions
	var connected_pos := [
		Vector2(step, 0), Vector2(-step, 0),
		Vector2(0, step), Vector2(0, -step),
	]

	for cell in flat_cells:
		if visited.has(cell):
			continue

		var group_id := groups.size()
		var group := {
			"cells": PackedVector2Array(),
			"is_coast_connect": false,
		}

		var queue: Array[Vector2] = [cell]
		visited[cell] = true

		while queue.size() > 0:
			var current := queue.pop_front() as Vector2

			group["cells"].append(current)
			cell_to_group[current] = group_id

			if coast_set.has(current):
				group["is_coast_connected"] = true

			for cp in connected_pos:
				var neighbour: Vector2 = current + cp
				if flat_set.has(neighbour) and not visited.has(neighbour):
					visited[neighbour] = true
					queue.push_back(neighbour)

		groups.append(group)

	return groups

func get_flat_cells(center: Vector2) -> PackedVector2Array:
	return flat_cells_cache[center]

func get_coast_cells(center: Vector2) -> PackedVector2Array:
	return coast_cells_cache[center]
	
