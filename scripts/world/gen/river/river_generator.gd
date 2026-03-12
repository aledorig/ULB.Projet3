class_name RiverGenerator
extends RefCounted

const MAX_ITERATIONS := 5

var terrain	  : TerrainGenerator
var grid	  : RiverGrid
var pathfinder: RiverPathfinder

func _init(p_terrain: TerrainGenerator, p_seed: int = 0) -> void:
	terrain    = p_terrain
	grid 	   = RiverGrid.new(p_terrain)
	pathfinder = RiverPathfinder.new(p_terrain, grid, p_seed)


func find_source(center: Vector2, area_size: float) -> Array[Vector3]:
	var step 							:= 80.0
	var half 							:= area_size / 2.0
	var possible_sources: Array[Vector3] = []
	var grid_count_x 					:= int(area_size / step)
	var grid_count_z 			     	:= int(area_size / step)

	for gx in range(grid_count_x):
		for gz in range(grid_count_z):
			var x := center.x - half + gx * step
			var z := center.y - half + gz * step
			var h := terrain.get_height(x, z)
			if h >= 130.0:
				possible_sources.append(Vector3(x, h, z))

	var sources: Array[Vector3] = []
	for cand in possible_sources:
		if _check_best_neighbour(cand, possible_sources):
			sources.append(cand)

	return sources

func _check_best_neighbour(cand: Vector3,
		possible_sources: Array[Vector3]) -> bool:

	var n_radius := 150.0

	for s in possible_sources:
		if cand.distance_to(s) <= n_radius:
			if -terrain.get_gradient(cand.x, cand.z) < \
			   -terrain.get_gradient(s.x, s.z):
				return false
	return true


func load_grid(center: Vector2, area_size: int) -> void:
	grid.load_grid(center, area_size)

func build_groups_bfs(center: Vector2) -> Array[Dictionary]:
	return grid.build_groups_bfs(center)


func build_river_path(source: Vector3, groups: Array[Dictionary],
		coast_cells: PackedVector2Array, flat_set: Dictionary) -> PackedVector3Array:

	var path: PackedVector3Array = []
	var cur_pos 				:= Vector2(source.x, source.z)
	var cur_h 					:= source.y
	var visited_grps: Dictionary = {}

	for it in range(MAX_ITERATIONS):
		var target := pathfinder.find_target_group(
			cur_pos, cur_h, groups, visited_grps
		)
		if target.is_empty():
			break

		var target_cell: Vector2 = target["cell"]
		var group_idx:   int     = target["group_idx"]
		visited_grps[group_idx]  = true

		var segment   := pathfinder.dijkstra_path(cur_pos, target_cell)
		var meandered := pathfinder.apply_meander(segment)
		path.append_array(pathfinder.segment_to_3d(meandered))

		var group: Dictionary = groups[group_idx]
		if group["is_coast_connected"]:
			var coast_seg := pathfinder.connect_to_coast(
				target_cell, group, coast_cells, flat_set
			)
			var coast_meander := pathfinder.apply_meander(coast_seg)
			path.append_array(pathfinder.segment_to_3d(coast_meander))
			break

		cur_pos = target_cell
		cur_h   = terrain.get_height(cur_pos.x, cur_pos.y)

	print("[RIVER] Built path with %d control points" % path.size())
	return path


func build_river_controls_points(source: Vector3) -> PackedVector3Array:
	var pos       := Vector2(source.x, source.z)
	var max_steps := 200
	var step_dist := 16.0

	var path: PackedVector3Array = []

	for i in range(max_steps):
		path.append(Vector3(pos.x, terrain.get_height(pos.x, pos.y), pos.y))

		var grad      := terrain.get_gradient(pos.x, pos.y)
		var slope     := -grad
		var slope_dir := slope.normalized()

		if slope.length() <= 1e-5:
			break

		pos += slope_dir * step_dist

	return path
