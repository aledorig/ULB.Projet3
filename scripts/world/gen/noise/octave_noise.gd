class_name OctaveNoise
extends RefCounted

var generators: Array[PerlinNoise]
var octave_count: int


func _init(rng: RandomNumberGenerator, p_octaves: int) -> void:
	octave_count = p_octaves
	generators = []
	generators.resize(p_octaves)
	for i in range(p_octaves):
		generators[i] = PerlinNoise.new(rng)


func get_value(x: float, z: float, x_scale: float, z_scale: float) -> float:
	var frequency: float = 1.0
	var amplitude: float = 1.0
	var result: float = 0.0

	for j in range(octave_count):
		result += generators[j].get_value(x * x_scale * frequency, z * z_scale * frequency) * amplitude
		frequency *= 2.0
		amplitude *= 0.5

	return result


func generate_octaves(out: PackedFloat32Array, x_off: float, z_off: float,
		x_size: int, z_size: int, x_scale: float, z_scale: float,
		max_octaves: int = -1) -> void:
	for i in range(out.size()):
		out[i] = 0.0

	var n: int = octave_count if max_octaves < 0 else mini(max_octaves, octave_count)
	var frequency: float = 1.0
	var amplitude: float = 1.0
	for j in range(n):
		generators[j].populate_noise_array(out,
			x_off * frequency * x_scale, z_off * frequency * z_scale,
			x_size, z_size, x_scale * frequency, z_scale * frequency, 1.0 / amplitude)
		frequency *= 2.0
		amplitude *= 0.5
