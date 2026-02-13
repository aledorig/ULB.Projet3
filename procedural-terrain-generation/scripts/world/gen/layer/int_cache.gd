class_name IntCache
extends RefCounted

const SMALL_ARRAY_SIZE: int = 256
const INITIAL_POOL_SIZE: int = 16

var _free_small: Array[PackedInt32Array] = []
var _free_large: Array[PackedInt32Array] = []
var _in_use_small: Array[PackedInt32Array] = []
var _in_use_large: Array[PackedInt32Array] = []
var _large_size: int = 256

static var _instance: IntCache = null

static func get_instance() -> IntCache:
	if _instance == null:
		_instance = IntCache.new()
	return _instance


func _init() -> void:
	for i in range(INITIAL_POOL_SIZE):
		var arr := PackedInt32Array()
		arr.resize(SMALL_ARRAY_SIZE)
		_free_small.append(arr)


func get_int_cache(size: int) -> PackedInt32Array:
	if size <= SMALL_ARRAY_SIZE:
		return _get_small_array()
	else:
		return _get_large_array(size)


func reset() -> void:
	_free_small.append_array(_in_use_small)
	_in_use_small.clear()

	_free_large.append_array(_in_use_large)
	_in_use_large.clear()


func _get_small_array() -> PackedInt32Array:
	var arr: PackedInt32Array

	if _free_small.is_empty():
		arr = PackedInt32Array()
		arr.resize(SMALL_ARRAY_SIZE)
	else:
		arr = _free_small.pop_back()

	_in_use_small.append(arr)
	return arr


func _get_large_array(size: int) -> PackedInt32Array:
	if size > _large_size:
		_large_size = size
		_free_large.clear()

	var arr: PackedInt32Array

	if _free_large.is_empty():
		arr = PackedInt32Array()
		arr.resize(_large_size)
	else:
		arr = _free_large.pop_back()
		if arr.size() < size:
			arr.resize(size)

	_in_use_large.append(arr)
	return arr


func get_stats() -> Dictionary:
	return {
		"free_small": _free_small.size(),
		"free_large": _free_large.size(),
		"in_use_small": _in_use_small.size(),
		"in_use_large": _in_use_large.size(),
		"large_size": _large_size,
	}
