class_name RiverPathfinder
extends RefCounted

const GRID_STEP := RiverGrid.GRID_STEP

const nb_samples_descent := 8
const uphill_penal := 100.0
const slope_w := 2.0
const flat_bonus := 0.5

const MEANDER_FREQ := 0.1
const MEANDER_AMP := 100.0
const SUBDIV_STEP := 32.0

var terrain: TerrainGenerator
var grid: RiverGrid
var m_noise: SimplexNoise


func _init(p_terrain: TerrainGenerator, p_grid: RiverGrid, p_seed: int) -> void:
	terrain = p_terrain
	grid = p_grid

	var rng := RandomNumberGenerator.new()
	rng.seed = p_seed + 7919
	m_noise = SimplexNoise.new(rng)


func find_target_group(start_pos: Vector2, h_start: float,
		groups: Array[Dictionary], visited_grps: Dictionary) -> Dictionary:
	
	var candidates: Array[Dictionary] = []
	for i in range(groups.size()):
		if visited_grps.has(i):
			continue

		var grp: Dictionary = groups[i]
		var cells: PackedVector2Array = grp["cells"]
		if cells.is_empty():
			continue

		var best_c := cells[0]
		var best_d := start_pos.distance_to(best_c)
		for c in cells:
			var d := start_pos.distance_to(c)
			if d < best_d:
				best_d = d
				best_c = c

		candidates.append({
			"group_idx": i,
			"cell": best_c,
			"distance": best_d,
		})

	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["distance"] < b["distance"]
	)

	for cand in candidates:
		if _check_descent(start_pos, h_start, cand["cell"]):
			return cand

	return {}

func _check_descent(start_pos: Vector2, h_start: float, to_pos: Vector2) -> bool:
	var prev_h := h_start
	for i in range(1, nb_samples_descent + 1):
		var t := float(i) / float(nb_samples_descent)
		var p := start_pos.lerp(to_pos, t)
		var h := terrain.get_height(p.x, p.y)

		if h > prev_h + 1.0:
			return false
		prev_h = h

	return true


## Uses Godot's built-in AStar3D for pathfinding.
## Reference: https://docs.godotengine.org/en/stable/classes/class_astar3d.html
func dijkstra_path(start: Vector2, goal: Vector2) -> PackedVector2Array:
	return _run_astar(start, goal, {}, false)


func dijkstra_path_flat_only(start: Vector2, goal: Vector2,
		flats: Dictionary) -> PackedVector2Array:
	return _run_astar(start, goal, flats, true)


func _run_astar(start: Vector2, goal: Vector2,
		flats: Dictionary, only_flat: bool) -> PackedVector2Array:

	var s := _snap(start)
	var g := _snap(goal)

	if s == g:
		return PackedVector2Array([s])

	var astar := AStar3D.new()
	var pos_to_id: Dictionary = {}
	var next_id: int = 0

	var margin := s.distance_to(g) * 0.5 + GRID_STEP * 2.0
	var min_x := minf(s.x, g.x) - margin
	var max_x := maxf(s.x, g.x) + margin
	var min_z := minf(s.y, g.y) - margin
	var max_z := maxf(s.y, g.y) + margin

	var half := GRID_STEP * 0.5
	var sx := floorf((min_x - half) / GRID_STEP) * GRID_STEP + half + GRID_STEP
	var sz := floorf((min_z - half) / GRID_STEP) * GRID_STEP + half + GRID_STEP

	var x := sx
	while x <= max_x:
		var z := sz
		while z <= max_z:
			var pos := Vector2(x, z)
			if only_flat and not flats.has(pos):
				z += GRID_STEP
				continue
			var h := terrain.get_height(pos.x, pos.y)
			var w := 1.0
			if grid.t_cache.has(pos):
				var samp: Vector2 = grid.t_cache[pos]
				if samp.y <= GRID_STEP / 8.0:
					w = flat_bonus
				else:
					w = 1.0 + samp.y * slope_w
			astar.add_point(next_id, Vector3(pos.x, h, pos.y), w)
			pos_to_id[pos] = next_id
			next_id += 1
			z += GRID_STEP
		x += GRID_STEP

	var offsets := [
		Vector2(GRID_STEP, 0), Vector2(-GRID_STEP, 0),
		Vector2(0, GRID_STEP), Vector2(0, -GRID_STEP),
	]
	for pos in pos_to_id:
		var id: int = pos_to_id[pos]
		for off in offsets:
			var nb: Vector2 = pos + off
			if pos_to_id.has(nb):
				astar.connect_points(id, pos_to_id[nb])

	if not pos_to_id.has(s) or not pos_to_id.has(g):
		return _subdiv_line(s, g)

	var path_3d := astar.get_point_path(pos_to_id[s], pos_to_id[g])
	if path_3d.is_empty():
		return _subdiv_line(s, g)

	var result := PackedVector2Array()
	for p in path_3d:
		result.append(Vector2(p.x, p.z))
	return result


func connect_to_coast(from_cell: Vector2, grp: Dictionary,
		coast_cells: PackedVector2Array, flats: Dictionary) -> PackedVector2Array:
	
	var grp_cells: PackedVector2Array = grp["cells"]

	var grp_set: Dictionary = {}
	for c in grp_cells:
		grp_set[c] = true

	var best_c := Vector2.ZERO
	var min_d := INF

	for cc in coast_cells:
		if grp_set.has(cc):
			var d := from_cell.distance_to(cc)
			if d < min_d:
				min_d = d
				best_c = cc

	if min_d == INF:
		for cc in coast_cells:
			var d := from_cell.distance_to(cc)
			if d < min_d:
				min_d = d
				best_c = cc

	if min_d == INF:
		return PackedVector2Array()

	var p_flat := dijkstra_path_flat_only(from_cell, best_c, flats)

	if p_flat.size() <= 2:
		return dijkstra_path(from_cell, best_c)

	return p_flat


func apply_meander(p_arr: PackedVector2Array) -> PackedVector2Array:
	var dense := _subdiv_path(p_arr)

	if dense.size() < 3:
		return dense

	var res := PackedVector2Array()
	res.append(dense[0])

	for i in range(1, dense.size() - 1):
		var p1 := dense[i - 1]
		var p2 := dense[i]
		var p3 := dense[i + 1]

		var dir := (p3 - p1).normalized()
		var perp := Vector2(-dir.y, dir.x)

		var n_val := m_noise.get_value(
			p2.x * MEANDER_FREQ,
			p2.y * MEANDER_FREQ
		)

		var off := perp * n_val * MEANDER_AMP
		res.append(p2 + off)

	res.append(dense[dense.size() - 1])
	return res


func _subdiv_path(p_arr: PackedVector2Array) -> PackedVector2Array:
	if p_arr.size() < 2:
		return p_arr

	var res := PackedVector2Array()
	res.append(p_arr[0])

	for i in range(1, p_arr.size()):
		var a := p_arr[i - 1]
		var b := p_arr[i]
		var d := a.distance_to(b)

		if d > SUBDIV_STEP:
			var steps := int(ceil(d / SUBDIV_STEP))
			for s in range(1, steps):
				var t := float(s) / float(steps)
				res.append(a.lerp(b, t))

		res.append(b)

	return res

func _subdiv_line(a: Vector2, b: Vector2) -> PackedVector2Array:
	var d := a.distance_to(b)
	var steps := maxi(int(ceil(d / SUBDIV_STEP)), 2)

	var res := PackedVector2Array()
	for i in range(steps + 1):
		var t := float(i) / float(steps)
		res.append(a.lerp(b, t))
	return res


func segment_to_3d(seg: PackedVector2Array) -> PackedVector3Array:
	var res := PackedVector3Array()
	for pt in seg:
		var h := terrain.get_height(pt.x, pt.y)
		res.append(Vector3(pt.x, h, pt.y))
	return res

func _snap(pos: Vector2) -> Vector2:
	var half := GRID_STEP * 0.5
	var gx := floorf((pos.x - half) / GRID_STEP) * GRID_STEP + half
	var gz := floorf((pos.y - half) / GRID_STEP) * GRID_STEP + half
	return Vector2(gx + GRID_STEP, gz + GRID_STEP)
