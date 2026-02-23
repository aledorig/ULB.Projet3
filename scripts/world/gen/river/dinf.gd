class_name Dinf
extends RefCounted

var terrain 	: TerrainGenerator
var area 		: int
var res 		: int
var center 		: Vector2
var HeightGrid 	: Array = []

var MOVE : Array[Vector2i] = [Vector2i(0,1), Vector2i(0,-1), Vector2i(-1,0), Vector2i(1,0), 
							  Vector2i(-1,-1), Vector2i(-1,1), Vector2i(1,1), Vector2i(1,-1)]

var Open 	: PriorityQueue
var Pit 	: Queue
var Labels 	: Array[Array]
var label 	: int

var CANDIDATE 	:= -2
var QUEUED 		:= -1

func _to_real_coordinate(cell:Vector2) -> Vector3:
	var step := res
	var half := area / 2.0
	
	var x := center.x - half + cell.x * step
	var z := center.y - half + cell.y * step
	var h := terrain.get_height(x, z)
	
	# carrefull y->h and z->z
	return Vector3(x,h,z)
	

func _init(p_center : Vector2, p_terrain : TerrainGenerator, covered_area : int, resolution : int) -> void:
	terrain = p_terrain
	center 	= p_center
	area 	= covered_area
	res 	= resolution

	Open = PriorityQueue.new()
	Pit = Queue.new()

	var step 		 := res
	var half 		 := area / 2.0
	var grid_count_x := int(area / step)
	var grid_count_z := int(area / step)
	
	# INIT LABEL
	label = 1
	
	# INIT LABELS
	Labels = []
	for gx in range(grid_count_x):
		var row : Array = []
		for gz in range(grid_count_z):
			row.append(CANDIDATE)
		Labels.append(row)
		
	# INIT HEIGHTMAP
	for gx in range(grid_count_x):
		var row = []
		for gz in range(grid_count_z):
			var real := _to_real_coordinate(Vector2(gx, gz))
			row.append(real.y)
		HeightGrid.append(row)
		
	# INIT BORDER MAP
	for i in range(grid_count_x):
		var cell_up   := _to_real_coordinate(Vector2(i,0))
		var cell_down := _to_real_coordinate(Vector2(i, grid_count_z - 1))

		Open.insert(Vector2(i, 0), cell_up.y)
		Open.insert(Vector2(i, grid_count_z - 1), cell_down.y)
		Labels[i][0] = QUEUED
		Labels[i][grid_count_z - 1] = QUEUED

	for i in range(1, grid_count_z - 1):
		var cell_left  := _to_real_coordinate(Vector2(0, i))
		var cell_right := _to_real_coordinate(Vector2(grid_count_x - 1, i))

		Open.insert(Vector2(0, i), cell_left.y)
		Open.insert(Vector2(grid_count_x - 1, i), cell_right.y)
		Labels[0][i] = QUEUED
		Labels[grid_count_x - 1][i] = QUEUED

	
func run() -> Array:
	var grid_count_x := int(area / res)
	var grid_count_z := int(area / res)
	
	var FilledMap : Array = []
	for gx in range(grid_count_x):
		FilledMap.append(HeightGrid[gx].duplicate())
	
	while not Open.empty() || not Pit.isEmpty():
		var c : Vector2
		
		if not Pit.isEmpty():
			c = Pit.pop()
		else:
			c = Open.extract()
		
		if Labels[c.x][c.y] == QUEUED:
			Labels[c.x][c.y] = label
			label += 1
			
		var c_z : float = FilledMap[c.x][c.y]
			
		# get the neigboors... + check if not outside...
		for move in MOVE:
			
			var nx := int(c.x) + move.x
			var ny := int(c.y) + move.y
			
			if nx < 0 or nx >= grid_count_x:
				continue
			if ny < 0 or ny >= grid_count_z:
				continue
			
			if Labels[nx][ny] != CANDIDATE:
				continue
			
			Labels[nx][ny] = Labels[c.x][c.y]
			
			var n_height : float = HeightGrid[nx][ny]
		
			if n_height <= c_z:
				FilledMap[nx][ny] = c_z
				Pit.push(Vector2(nx, ny))
			else:
				Open.insert(Vector2(nx, ny), n_height)

	return FilledMap


func extract_lakes(filled_map: Array) -> Array[Dictionary]:
	var grid_count_x := int(area / res)
	var grid_count_z := int(area / res)
	var epsilon := 0.01

	# Mark which cells are lake cells
	var is_lake := []
	for gx in range(grid_count_x):
		var row := []
		for gz in range(grid_count_z):
			row.append(filled_map[gx][gz] - HeightGrid[gx][gz] > epsilon)
		is_lake.append(row)

	# Flood-fill to group connected lake cells
	var visited := []
	for gx in range(grid_count_x):
		var row := []
		for gz in range(grid_count_z):
			row.append(false)
		visited.append(row)

	var lakes: Array[Dictionary] = []

	for gx in range(grid_count_x):
		for gz in range(grid_count_z):
			if not is_lake[gx][gz] or visited[gx][gz]:
				continue

			# BFS flood fill for this lake
			var cells: Array[Vector2] = []
			var water_level: float = filled_map[gx][gz]
			var queue: Array[Vector2i] = [Vector2i(gx, gz)]
			visited[gx][gz] = true

			while queue.size() > 0:
				var cell: Vector2i = queue.pop_front()
				cells.append(Vector2(cell.x, cell.y))
				water_level = maxf(water_level, filled_map[cell.x][cell.y])

				for move in MOVE:
					var nx: int = cell.x + move.x
					var ny: int = cell.y + move.y
					if nx < 0 or nx >= grid_count_x or ny < 0 or ny >= grid_count_z:
						continue
					if visited[nx][ny] or not is_lake[nx][ny]:
						continue
					visited[nx][ny] = true
					queue.append(Vector2i(nx, ny))

			# Compute world bounds
			var min_world := Vector2(INF, INF)
			var max_world := Vector2(-INF, -INF)
			for cell in cells:
				var world_pos := _to_real_coordinate(cell)
				min_world.x = minf(min_world.x, world_pos.x)
				min_world.y = minf(min_world.y, world_pos.z)
				max_world.x = maxf(max_world.x, world_pos.x)
				max_world.y = maxf(max_world.y, world_pos.z)

			var bounds := Rect2(min_world, max_world - min_world)

			lakes.append({
				"water_level": water_level,
				"cells": cells,
				"world_bounds": bounds,
			})

	return lakes
