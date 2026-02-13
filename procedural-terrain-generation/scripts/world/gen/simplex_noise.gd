class_name SimplexNoise
extends RefCounted

const GRAD_X: PackedFloat64Array = [1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 1.0, -1.0, 0.0, 0.0, 0.0, 0.0]
const GRAD_Z: PackedFloat64Array = [1.0, 1.0, -1.0, -1.0, 0.0, 0.0, 0.0, 0.0, 1.0, -1.0, 1.0, -1.0]

const SQRT_3: float = 1.7320508075688772
const F2: float = 0.5 * (SQRT_3 - 1.0)    # skew factor
const G2: float = (3.0 - SQRT_3) / 6.0     # unskew factor

var perm: PackedInt32Array
var x_offset: float
var z_offset: float


func _init(rng: RandomNumberGenerator) -> void:
	x_offset = rng.randf() * 256.0
	z_offset = rng.randf() * 256.0
	var _unused: float = rng.randf() * 256.0  # advance rng

	perm = PackedInt32Array()
	perm.resize(512)
	for i in range(256):
		perm[i] = i

	for l in range(256):
		var j: int = rng.randi_range(l, 255)
		var k: int = perm[l]
		perm[l] = perm[j]
		perm[j] = k
		perm[l + 256] = perm[l]


static func _fast_floor(v: float) -> int:
	var vi: int = int(v)
	return vi - 1 if v < float(vi) else vi


func get_value(x: float, z: float) -> float:
	var s: float = (x + z) * F2
	var i: int = _fast_floor(x + s)
	var j: int = _fast_floor(z + s)

	var t: float = float(i + j) * G2
	var x0: float = x - (float(i) - t)
	var z0: float = z - (float(j) - t)

	var i1: int
	var j1: int
	if x0 > z0:
		i1 = 1; j1 = 0
	else:
		i1 = 0; j1 = 1

	var x1: float = x0 - float(i1) + G2
	var z1: float = z0 - float(j1) + G2
	var x2: float = x0 - 1.0 + 2.0 * G2
	var z2: float = z0 - 1.0 + 2.0 * G2

	var ii: int = i & 255
	var jj: int = j & 255
	var gi0: int = perm[ii + perm[jj]] % 12
	var gi1: int = perm[ii + i1 + perm[jj + j1]] % 12
	var gi2: int = perm[ii + 1 + perm[jj + 1]] % 12

	var t0: float = 0.5 - x0 * x0 - z0 * z0
	var n0: float
	if t0 < 0.0:
		n0 = 0.0
	else:
		t0 *= t0
		n0 = t0 * t0 * (GRAD_X[gi0] * x0 + GRAD_Z[gi0] * z0)

	var t1: float = 0.5 - x1 * x1 - z1 * z1
	var n1: float
	if t1 < 0.0:
		n1 = 0.0
	else:
		t1 *= t1
		n1 = t1 * t1 * (GRAD_X[gi1] * x1 + GRAD_Z[gi1] * z1)

	var t2: float = 0.5 - x2 * x2 - z2 * z2
	var n2: float
	if t2 < 0.0:
		n2 = 0.0
	else:
		t2 *= t2
		n2 = t2 * t2 * (GRAD_X[gi2] * x2 + GRAD_Z[gi2] * z2)

	return 70.0 * (n0 + n1 + n2)


func add(out: PackedFloat32Array, x_off: float, z_off: float,
		x_size: int, z_size: int, x_scale: float, z_scale: float,
		amplitude: float) -> void:
	var idx: int = 0

	for gz in range(z_size):
		var d0: float = (z_off + float(gz)) * z_scale + z_offset

		for gx in range(x_size):
			var d1: float = (x_off + float(gx)) * x_scale + x_offset

			var s: float = (d1 + d0) * F2
			var i: int = _fast_floor(d1 + s)
			var j: int = _fast_floor(d0 + s)

			var t: float = float(i + j) * G2
			var x0: float = d1 - (float(i) - t)
			var z0: float = d0 - (float(j) - t)

			var i1: int
			var j1: int
			if x0 > z0:
				i1 = 1; j1 = 0
			else:
				i1 = 0; j1 = 1

			var x1: float = x0 - float(i1) + G2
			var z1: float = z0 - float(j1) + G2
			var x2: float = x0 - 1.0 + 2.0 * G2
			var z2: float = z0 - 1.0 + 2.0 * G2

			var ii: int = i & 255
			var jj: int = j & 255
			var gi0: int = perm[ii + perm[jj]] % 12
			var gi1: int = perm[ii + i1 + perm[jj + j1]] % 12
			var gi2: int = perm[ii + 1 + perm[jj + 1]] % 12

			var t0: float = 0.5 - x0 * x0 - z0 * z0
			var n0: float
			if t0 < 0.0:
				n0 = 0.0
			else:
				t0 *= t0
				n0 = t0 * t0 * (GRAD_X[gi0] * x0 + GRAD_Z[gi0] * z0)

			var t1: float = 0.5 - x1 * x1 - z1 * z1
			var n1: float
			if t1 < 0.0:
				n1 = 0.0
			else:
				t1 *= t1
				n1 = t1 * t1 * (GRAD_X[gi1] * x1 + GRAD_Z[gi1] * z1)

			var t2: float = 0.5 - x2 * x2 - z2 * z2
			var n2: float
			if t2 < 0.0:
				n2 = 0.0
			else:
				t2 *= t2
				n2 = t2 * t2 * (GRAD_X[gi2] * x2 + GRAD_Z[gi2] * z2)

			out[idx] += 70.0 * (n0 + n1 + n2) * amplitude
			idx += 1
