class_name OctaveNoise
extends RefCounted

## FBM wrapper which layers N PerlinNoise octaves

var generators: Array[PerlinNoise]
var octave_count: int


func _init(rng: RandomNumberGenerator, p_octaves: int) -> void:
	octave_count = p_octaves
	generators = []
	generators.resize(p_octaves)
	for i in range(p_octaves):
		generators[i] = PerlinNoise.new(rng)


# Single-point FBM: frequency doubles, amplitude halves per octave
func get_value(x: float, z: float, x_scale: float, z_scale: float) -> float:
	var frequency: float = 1.0
	var amplitude: float = 1.0
	var result: float = 0.0
	for j in range(octave_count):
		result += generators[j].get_value(x * x_scale * frequency, z * z_scale * frequency) * amplitude
		frequency *= 2.0
		amplitude *= 0.5
	return result


# Batch FBM: frequency doubles, amplitude halves per octave
func generate_octaves(out: PackedFloat32Array, x_off: float, z_off: float,
		x_size: int, z_size: int, x_scale: float, z_scale: float) -> void:
	for i in range(out.size()):
		out[i] = 0.0

	var frequency: float = 1.0
	var amplitude: float = 1.0
	for j in range(octave_count):
		# populate_noise_array accumulates: out[i] += result * (1.0 / noise_scale)
		# So noise_scale = 1.0 / amplitude to get the right per-octave weight
		generators[j].populate_noise_array(out,
			x_off * frequency * x_scale, z_off * frequency * z_scale,
			x_size, z_size, x_scale * frequency, z_scale * frequency, 1.0 / amplitude)
		frequency *= 2.0
		amplitude *= 0.5
