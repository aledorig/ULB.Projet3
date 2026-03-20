class_name MeshCache
extends RefCounted

var _cache: Dictionary = { }
var _access_order: Array[Vector2i] = []
var _max_size: int


func _init(max_size: int) -> void:
	_max_size = max_size


func has(pos: Vector2i) -> bool:
	return _cache.has(pos)


func get_mesh(pos: Vector2i) -> ArrayMesh:
	return _cache.get(pos)


func store(pos: Vector2i, mesh: ArrayMesh) -> void:
	if _cache.size() >= _max_size:
		var oldest = _access_order.pop_front()
		_cache.erase(oldest)

	_cache[pos] = mesh
	_access_order.append(pos)


func clear() -> void:
	_cache.clear()
	_access_order.clear()


func size() -> int:
	return _cache.size()
