class_name NoiseFactory
extends RefCounted


static func make_perlin(rng: RandomNumberGenerator) -> PerlinNoise:
  var perm := _build_perm(rng)
  var noise := PerlinNoise.new()
  noise.setup(rng.randf() * 256.0, rng.randf() * 256.0, perm)
  return noise


static func make_simplex(rng: RandomNumberGenerator) -> SimplexNoise:
  var perm := _build_perm(rng)
  var noise := SimplexNoise.new()
  noise.setup(rng.randf() * 256.0, rng.randf() * 256.0, perm)
  var _unused: float = rng.randf() * 256.0 # advance rng to match old SimplexNoise._init
  return noise


static func make_octave(rng: RandomNumberGenerator, p_octaves: int) -> OctaveNoise:
  var offsets_x := PackedFloat32Array()
  var offsets_z := PackedFloat32Array()
  var all_perms := PackedInt32Array()

  offsets_x.resize(p_octaves)
  offsets_z.resize(p_octaves)
  all_perms.resize(p_octaves * 512)

  for i in range(p_octaves):
    offsets_x[i] = rng.randf() * 256.0
    offsets_z[i] = rng.randf() * 256.0

    var perm := _build_perm(rng)
    for j in range(256):
      all_perms[i * 512 + j] = perm[j]
      all_perms[i * 512 + j + 256] = perm[j]

  var noise := OctaveNoise.new()
  noise.setup(offsets_x, offsets_z, all_perms, p_octaves)
  return noise


static func _build_perm(rng: RandomNumberGenerator) -> PackedInt32Array:
  var perm := PackedInt32Array()
  perm.resize(256)

  for i in range(256):
    perm[i] = i

  for i in range(256):
    var j: int = rng.randi_range(i, 255)
    var tmp: int = perm[i]
    perm[i] = perm[j]
    perm[j] = tmp

  return perm
