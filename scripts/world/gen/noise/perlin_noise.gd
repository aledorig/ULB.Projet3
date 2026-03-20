class_name PerlinNoise
extends RefCounted

# 16 gradient directions
const GRAD_X: PackedFloat64Array = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, 0.0, -1.0, 0.0]
const GRAD_Z: PackedFloat64Array = [0.0, 0.0, 0.0, 0.0, 1.0, 1.0, -1.0, -1.0, 1.0, 1.0, -1.0, -1.0, 0.0, 1.0, 0.0, -1.0]

var x_offset: float
var z_offset: float
var _perm_table: PackedInt32Array


func _init(rng: RandomNumberGenerator) -> void:
	x_offset = rng.randf() * 256.0
	z_offset = rng.randf() * 256.0
	_build_perm_table(rng)


func get_value(x: float, z: float) -> float:
	return _perlin_2d(x + x_offset, z + z_offset)


func populate_noise_array(
		out: PackedFloat32Array,
		x_offset_param: float,
		z_offset_param: float,
		x_size: int,
		z_size: int,
		x_scale: float,
		z_scale: float,
		noise_scale: float,
) -> void:
	var inv_scale: float = 1.0 / noise_scale
	var perm := _perm_table
	var gx_arr := GRAD_X
	var gz_arr := GRAD_Z
	var self_xo: float = x_offset
	var self_zo: float = z_offset

	var idx: int = 0

	# Z-outer, X-inner to match terrain_generator's row-major layout
	for gz in range(z_size):
		var real_z: float = z_offset_param + gz * z_scale + self_zo
		var zi: int = int(real_z)

		if real_z < float(zi):
			zi -= 1

		var z0: int = zi & 255
		real_z -= float(zi)

		var fz: float = real_z * real_z * real_z * (real_z * (real_z * 6.0 - 15.0) + 10.0)

		for gx in range(x_size):
			var real_x: float = x_offset_param + gx * x_scale + self_xo
			var xi: int = int(real_x)

			if real_x < float(xi):
				xi -= 1

			var x0: int = xi & 255
			real_x -= float(xi)

			var fx: float = real_x * real_x * real_x * (real_x * (real_x * 6.0 - 15.0) + 10.0)

			var a_hash: int = perm[x0]
			var aa: int = perm[a_hash] + z0
			var b_hash: int = perm[x0 + 1]
			var ba: int = perm[b_hash] + z0

			var g: int = perm[aa] & 15
			var d00: float = gx_arr[g] * real_x + gz_arr[g] * real_z

			g = perm[ba] & 15
			var d10: float = gx_arr[g] * (real_x - 1.0) + gz_arr[g] * real_z

			g = perm[aa + 1] & 15
			var d01: float = gx_arr[g] * real_x + gz_arr[g] * (real_z - 1.0)

			g = perm[ba + 1] & 15
			var d11: float = gx_arr[g] * (real_x - 1.0) + gz_arr[g] * (real_z - 1.0)

			var lx0: float = d00 + (d10 - d00) * fx
			var lx1: float = d01 + (d11 - d01) * fx
			var result: float = lx0 + (lx1 - lx0) * fz

			out[idx] += result * inv_scale
			idx += 1


func _build_perm_table(rng: RandomNumberGenerator) -> void:
	_perm_table = PackedInt32Array()
	_perm_table.resize(512)

	for i in range(256):
		_perm_table[i] = i

	for i in range(256):
		var j: int = rng.randi_range(i, 255)
		var tmp: int = _perm_table[i]
		_perm_table[i] = _perm_table[j]
		_perm_table[j] = tmp
		_perm_table[i + 256] = _perm_table[i]


func _perlin_2d(x: float, z: float) -> float:
	var xi: int = int(floorf(x))
	var zi: int = int(floorf(z))
	var x0: int = xi & 255
	var z0: int = zi & 255

	var lx: float = x - xi
	var lz: float = z - zi

	var a_hash: int = _perm_table[x0]
	var aa: int = _perm_table[a_hash] + z0
	var b_hash: int = _perm_table[x0 + 1]
	var ba: int = _perm_table[b_hash] + z0

	var g: int = _perm_table[aa] & 15
	var d00: float = GRAD_X[g] * lx + GRAD_Z[g] * lz

	g = _perm_table[ba] & 15
	var d10: float = GRAD_X[g] * (lx - 1.0) + GRAD_Z[g] * lz

	g = _perm_table[aa + 1] & 15
	var d01: float = GRAD_X[g] * lx + GRAD_Z[g] * (lz - 1.0)

	g = _perm_table[ba + 1] & 15
	var d11: float = GRAD_X[g] * (lx - 1.0) + GRAD_Z[g] * (lz - 1.0)

	var fx: float = lx * lx * lx * (lx * (lx * 6.0 - 15.0) + 10.0)
	var fz: float = lz * lz * lz * (lz * (lz * 6.0 - 15.0) + 10.0)

	var ix0: float = d00 + (d10 - d00) * fx
	var ix1: float = d01 + (d11 - d01) * fx
	return ix0 + (ix1 - ix0) * fz
