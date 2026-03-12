class_name RiverGrid
extends RefCounted

# roughly 1/3 chunk
const GRID_STEP := 64.0

var terrain: TerrainGenerator
var t_cache: Dictionary[Vector2, Vector2] = {} # (height, slope_mag)
var coast_cache: Dictionary[Vector2, PackedVector2Array] = {}
var flat_cache: Dictionary[Vector2, PackedVector2Array] = {}

func _init(p_terrain: TerrainGenerator) -> void:
	terrain = p_terrain
	t_cache = {}
	coast_cache = {}
	flat_cache = {}

func cached_cell(pos: Vector2) -> Vector2:
	if t_cache.has(pos):
		return t_cache[pos]

	var h := terrain.get_height(pos.x, pos.y)
	var grad := -terrain.get_gradient(pos.x, pos.y)
	var slope_mag := grad.length()

	var samp: Vector2 = Vector2(h, slope_mag)
	t_cache[pos] = samp
	return samp


func load_grid(center: Vector2, area_size: int) -> void:
	var step := GRID_STEP
	var lvl_sea := 0.0
	var lvl_mountains := 130.0

	var slope_thr := step / 8.0
	var d_height_thr := step / 2.0

	var half := float(area_size) * 0.5
	var origin := center - Vector2(half, half)

	var cells_x := int(floor(float(area_size) / step))
	var cells_z := int(floor(float(area_size) / step))

	var coast_c := PackedVector2Array()
	var flat_c := PackedVector2Array()

	for gx in range(cells_x):
		for gz in range(cells_z):
			var x0 := origin.x + gx * step
			var z0 := origin.y + gz * step

			var bl := Vector2(x0, z0)
			var br := Vector2(x0 + step, z0)
			var ul := Vector2(x0, z0 + step)
			var ur := Vector2(x0 + step, z0 + step)

			var cc := Vector2(x0 + step * 0.5, z0 + step * 0.5)

			var v_bl := cached_cell(bl)
			var v_br := cached_cell(br)
			var v_ul := cached_cell(ul)
			var v_ur := cached_cell(ur)
			var v_cc := cached_cell(cc)

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

			var min_h := minf(minf(hbl, hbr), minf(minf(hul, hur), hcc))
			var max_h := maxf(maxf(hbl, hbr), maxf(maxf(hul, hur), hcc))

			# straddles sea level -> coast
			if hcc > 0.0 and min_h <= 0.0 and max_h >= 0.0:
				coast_c.append(cc)

			var avg_slope := (sbl + sbr + sul + sur + scc) / 5.0
			var delta_h := max_h - min_h

			# low slope + small height delta = flat terrain rivers can cross
			if hcc > lvl_sea and hcc <= lvl_mountains \
			and avg_slope <= slope_thr \
			and delta_h <= d_height_thr:
				flat_c.append(cc)

	coast_cache[center] = coast_c
	flat_cache[center] = flat_c


func build_groups_bfs(center: Vector2) -> Array[Dictionary]:
	var step := GRID_STEP
	var flat_c := flat_cache[center]
	var coast_c := coast_cache[center]

	var flat_set: Dictionary = {}
	for c in flat_c:
		flat_set[c] = true

	var coast_set: Dictionary = {}
	for c in coast_c:
		coast_set[c] = true

	var visited: Dictionary = {}
	var groups: Array[Dictionary] = []

	var conn_pos := [
		Vector2(step, 0), Vector2(-step, 0),
		Vector2(0, step), Vector2(0, -step),
	]

	for c in flat_c:
		if visited.has(c):
			continue

		var grp := {
			"cells": PackedVector2Array(),
			"is_coast_connected": false,
		}

		var queue: Array[Vector2] = [c]
		visited[c] = true

		while queue.size() > 0:
			var curr := queue.pop_front() as Vector2

			grp["cells"].append(curr)

			if coast_set.has(curr):
				grp["is_coast_connected"] = true

			for cp in conn_pos:
				var nb: Vector2 = curr + cp
				if flat_set.has(nb) and not visited.has(nb):
					visited[nb] = true
					queue.push_back(nb)

		groups.append(grp)

	return groups


func build_flat_set(center: Vector2) -> Dictionary:
	var f_set: Dictionary = {}
	for c in flat_cache[center]:
		f_set[c] = true
	return f_set
