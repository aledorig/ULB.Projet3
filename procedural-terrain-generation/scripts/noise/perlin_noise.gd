class_name PerlinNoise
extends RefCounted

## GDScript port of the Python Perlin noise implementation (scripts/noise/perlin.py)
##
## Perlin noise is a gradient noise algorithm invented by Ken Perlin. It produces
## smooth, natural-looking pseudo-random values by:
##   1. Dividing space into a regular grid
##   2. Assigning a random gradient vector to each grid vertex
##   3. For any point, computing the dot product between each surrounding corner's
##      gradient and the vector from that corner to the point
##   4. Interpolating those dot products using a smooth fade curve
##
## The result is continuous noise that tiles seamlessly and has no obvious
## repetition at human-perceivable scales.
##
## This implementation also supports Fractal Brownian Motion (FBM), which layers
## multiple octaves of Perlin noise at increasing frequencies and decreasing
## amplitudes to produce richer, more detailed terrain.


# ============================================================================
# CONSTANTS
# ============================================================================

## The 8 unit-length gradient directions used at grid vertices.
## Each grid corner gets one of these via a hash lookup into the permutation
## table. Using only 8 axis-aligned and diagonal directions keeps the math
## simple while producing visually smooth noise.
const DIRECTIONS: Array[Vector2] = [
	Vector2(1.0, 1.0),
	Vector2(-1.0, 1.0),
	Vector2(1.0, -1.0),
	Vector2(-1.0, -1.0),
	Vector2(1.0, 0.0),
	Vector2(-1.0, 0.0),
	Vector2(0.0, 1.0),
	Vector2(0.0, -1.0),
]


# ============================================================================
# PROPERTIES
# ============================================================================

## Number of FBM octaves. Each octave adds finer detail at higher frequency.
## More octaves = more detail but slower computation.
var fractal_octaves: int

## How much each successive octave's amplitude is scaled down (typically 0.5).
## Lower gain means higher octaves contribute less, producing smoother terrain.
var fractal_gain: float

## How much each successive octave's frequency is scaled up (typically 2.0).
## Higher lacunarity means each octave covers finer detail.
var fractal_lacunarity: float

## Base frequency applied before octave scaling. Controls the overall "zoom"
## level of the noise. Smaller values produce larger, gentler features.
var base_frequency: float

## The seed used to build the permutation table. Same seed = same noise.
var noise_seed: int

## Permutation table used for pseudo-random gradient selection.
## This is a 512-entry array (256 shuffled values, duplicated) that converts
## any grid coordinate into a repeatable pseudo-random index. The duplication
## to 512 entries avoids needing modulo operations when hashing two coordinates:
## table[table[x] + y] can safely index up to 255 + 255 = 510.
## PackedInt32Array is used instead of Array[int] for contiguous memory layout
## and faster indexed access in tight inner loops.
var _perm_table: PackedInt32Array


# ============================================================================
# INITIALIZATION
# ============================================================================

func _init(
	p_octaves: int = 1,
	p_gain: float = 0.5,
	p_lacunarity: float = 2.0,
	p_seed: int = 0
) -> void:
	fractal_octaves = p_octaves
	fractal_gain = p_gain
	fractal_lacunarity = p_lacunarity
	base_frequency = 0.05
	noise_seed = p_seed
	_build_perm_table(p_seed)


# ============================================================================
# PUBLIC API
# ============================================================================

func set_seed(p_seed: int) -> void:
	## Reseed the noise generator. Rebuilds the permutation table so all
	## subsequent noise queries produce a different but deterministic pattern.
	noise_seed = p_seed
	_build_perm_table(p_seed)


func get_noise_2d(x: float, z: float) -> float:
	## Sample the noise at world coordinates (x, z), layering multiple octaves
	## of Perlin noise via Fractal Brownian Motion (FBM).
	##
	## FBM works by summing several "octaves" of the same noise function, where
	## each octave has:
	##   - Higher frequency (controlled by fractal_lacunarity): captures finer detail
	##   - Lower amplitude  (controlled by fractal_gain): so fine detail doesn't
	##     overpower the broad shape
	##
	## The result is clamped to [-1.0, 1.0].
	##
	## NOTE: The Python reference uses range(fractal_octaves + 1), meaning
	## octaves=4 would run 5 iterations. This port uses fractal_octaves directly,
	## so octaves=4 means exactly 4 iterations, matching FastNoiseLite convention.
	var amplitude: float = 1.0
	var frequency: float = base_frequency
	var noise_value: float = 0.0

	for _i in range(fractal_octaves):
		noise_value += _perlin_2d(x * frequency, z * frequency) * amplitude
		amplitude *= fractal_gain
		frequency *= fractal_lacunarity

	return clampf(noise_value, -1.0, 1.0)


func fill_noise_grid(
	origin_x: float, origin_z: float,
	width: int, height: int,
	spacing: float,
	out: PackedFloat32Array
) -> void:
	## Fill a pre-sized PackedFloat32Array with noise values for an entire grid.
	## This is MUCH faster than calling get_noise_2d() per-vertex because:
	##   - Eliminates ~1,764 function calls to get_noise_2d
	##   - Eliminates ~7,056 function calls to _perlin_2d (4 octaves × 1,764 verts)
	##   - Precomputes octave frequencies/amplitudes once
	##   - Keeps all computation in a single GDScript scope (fewer variable lookups)

	# Precompute per-octave frequency and amplitude
	var oct_freq: PackedFloat64Array = PackedFloat64Array()
	var oct_amp: PackedFloat64Array = PackedFloat64Array()
	oct_freq.resize(fractal_octaves)
	oct_amp.resize(fractal_octaves)
	var f: float = base_frequency
	var a: float = 1.0
	for o in range(fractal_octaves):
		oct_freq[o] = f
		oct_amp[o] = a
		f *= fractal_lacunarity
		a *= fractal_gain

	var perm := _perm_table  # local reference (faster access in GDScript)
	var dirs := DIRECTIONS

	var ni: int = 0
	for gz in range(height):
		var world_z: float = origin_z + gz * spacing
		for gx in range(width):
			var world_x: float = origin_x + gx * spacing

			# --- FBM accumulation (inlined) ---
			var noise_value: float = 0.0

			for o in range(fractal_octaves):
				var freq: float = oct_freq[o]
				var px: float = world_x * freq
				var pz: float = world_z * freq

				# --- Perlin 2D (fully inlined) ---
				var x_floor: int = int(floorf(px))
				var z_floor: int = int(floorf(pz))
				var x0: int = x_floor & 255
				var z0: int = z_floor & 255
				var x1: int = (x0 + 1) & 255
				var z1: int = (z0 + 1) & 255

				var lx: float = px - x_floor
				var lz: float = pz - z_floor

				# Corner gradients + dot products
				var g: Vector2 = dirs[perm[perm[x0] + z0] & 7]
				var d_bl: float = g.x * lx + g.y * lz

				g = dirs[perm[perm[x1] + z0] & 7]
				var d_br: float = g.x * (lx - 1.0) + g.y * lz

				g = dirs[perm[perm[x0] + z1] & 7]
				var d_tl: float = g.x * lx + g.y * (lz - 1.0)

				g = dirs[perm[perm[x1] + z1] & 7]
				var d_tr: float = g.x * (lx - 1.0) + g.y * (lz - 1.0)

				# Quintic fade
				var lx2: float = lx * lx
				var lx3: float = lx2 * lx
				var fx: float = 6.0 * lx3 * lx2 - 15.0 * lx2 * lx2 + 10.0 * lx3

				var lz2: float = lz * lz
				var lz3: float = lz2 * lz
				var fz: float = 6.0 * lz3 * lz2 - 15.0 * lz2 * lz2 + 10.0 * lz3

				# Bilinear interpolation
				var ix0: float = d_bl + (d_br - d_bl) * fx
				var ix1: float = d_tl + (d_tr - d_tl) * fx
				noise_value += (ix0 + (ix1 - ix0) * fz) * oct_amp[o]

			out[ni] = clampf(noise_value, -1.0, 1.0)
			ni += 1


# ============================================================================
# PERMUTATION TABLE
# ============================================================================

func _build_perm_table(p_seed: int) -> void:
	## Build a deterministic permutation table from the given seed.
	##
	## The permutation table is the heart of Perlin noise's pseudo-randomness.
	## It maps any grid coordinate to a seemingly random but repeatable value.
	## We create a list [0..255], shuffle it with a seeded RNG using
	## Fisher-Yates, then duplicate it to 512 entries so that the two-level
	## hash (table[table[x] + y]) never goes out of bounds.

	# Start with identity [0, 1, 2, ..., 255]
	var table: PackedInt32Array = PackedInt32Array()
	table.resize(256)
	for i: int in range(256):
		table[i] = i

	# Fisher-Yates shuffle with a seeded RandomNumberGenerator for determinism.
	# We iterate from the last index down to 0, swapping each element with a
	# random earlier (or same) element. This produces a uniformly random
	# permutation that is fully determined by the seed.
	var rng: RandomNumberGenerator = RandomNumberGenerator.new()
	rng.seed = p_seed

	for i: int in range(255, -1, -1):
		# rng.randi_range(0, i) is inclusive on both ends, same as Python's
		# random.randint(0, i), so the Fisher-Yates logic is identical.
		var j: int = rng.randi_range(0, i)
		var tmp: int = table[i]
		table[i] = table[j]
		table[j] = tmp

	# Duplicate to 512 entries: table[table[x] + y] can index up to 510
	_perm_table = PackedInt32Array()
	_perm_table.resize(512)
	for i: int in range(256):
		_perm_table[i] = table[i]
		_perm_table[i + 256] = table[i]


# ============================================================================
# CORE PERLIN ALGORITHM (fully inlined for performance)
# ============================================================================

func _perlin_2d(x: float, z: float) -> float:
	## Compute a single octave of 2D Perlin noise at (x, z).
	##
	## All helper operations (grid lookup, gradient selection, dot products,
	## fade curve, and linear interpolation) are inlined here to avoid the
	## overhead of GDScript method calls in hot loops.

	# ------------------------------------------------------------------
	# STEP 1: Find grid cell coordinates
	# ------------------------------------------------------------------
	# Floor the input to find which unit grid cell the point falls in.
	# The & 255 wraps the coordinate into [0, 255] so the permutation
	# table lookups stay in bounds. This also makes the noise tile every
	# 256 units (which is fine for terrain generation).
	var x_floor: int = int(floorf(x))
	var z_floor: int = int(floorf(z))
	var x0: int = x_floor & 255
	var z0: int = z_floor & 255
	var x1: int = (x0 + 1) & 255
	var z1: int = (z0 + 1) & 255

	# Local position of the point within the unit cell, in [0, 1).
	# These fractional offsets determine how we blend the four corner
	# contributions.
	var local_x: float = x - x_floor
	var local_z: float = z - z_floor

	# ------------------------------------------------------------------
	# STEP 2: Compute the 4 corner contributions
	# ------------------------------------------------------------------
	# For each of the four corners of the grid cell:
	#   a) Look up a pseudo-random gradient vector via the permutation table
	#   b) Compute the vector from that corner to the input point
	#   c) Dot product the gradient with the distance vector
	#
	# The dot product measures "how much the point aligns with the corner's
	# gradient direction". Positive = the point is in the gradient's
	# direction, negative = opposite.

	# --- Bottom-left corner (0, 0) ---
	var hash_bl: int = _perm_table[_perm_table[x0] + z0]
	var grad_bl: Vector2 = DIRECTIONS[hash_bl & 7]
	var dot_bl: float = grad_bl.x * local_x + grad_bl.y * local_z

	# --- Bottom-right corner (1, 0) ---
	var hash_br: int = _perm_table[_perm_table[x1] + z0]
	var grad_br: Vector2 = DIRECTIONS[hash_br & 7]
	var dot_br: float = grad_br.x * (local_x - 1.0) + grad_br.y * local_z

	# --- Top-left corner (0, 1) ---
	var hash_tl: int = _perm_table[_perm_table[x0] + z1]
	var grad_tl: Vector2 = DIRECTIONS[hash_tl & 7]
	var dot_tl: float = grad_tl.x * local_x + grad_tl.y * (local_z - 1.0)

	# --- Top-right corner (1, 1) ---
	var hash_tr: int = _perm_table[_perm_table[x1] + z1]
	var grad_tr: Vector2 = DIRECTIONS[hash_tr & 7]
	var dot_tr: float = grad_tr.x * (local_x - 1.0) + grad_tr.y * (local_z - 1.0)

	# ------------------------------------------------------------------
	# STEP 3: Fade curves (quintic smoothstep)
	# ------------------------------------------------------------------
	# The fade function f(t) = 6t^5 - 15t^4 + 10t^3 is a quintic
	# polynomial chosen so that:
	#   - f(0) = 0, f(1) = 1             (interpolation endpoints match)
	#   - f'(0) = f'(1) = 0              (first derivative is zero at edges)
	#   - f''(0) = f''(1) = 0            (second derivative is zero at edges)
	#
	# Having both first and second derivatives vanish at 0 and 1 means the
	# noise is C2-continuous across grid cell boundaries. This prevents
	# visible seams or "grid artifacts" that would appear with simpler
	# interpolation (like linear lerp or even Hermite/cubic smoothstep).
	#
	# Ken Perlin originally used 3t^2 - 2t^3 (cubic) but upgraded to the
	# quintic version in his "Improving Noise" paper (2002) for smoother
	# second derivatives.
	var lx2: float = local_x * local_x
	var lx3: float = lx2 * local_x
	var fade_x: float = 6.0 * lx3 * lx2 - 15.0 * lx2 * lx2 + 10.0 * lx3

	var lz2: float = local_z * local_z
	var lz3: float = lz2 * local_z
	var fade_z: float = 6.0 * lz3 * lz2 - 15.0 * lz2 * lz2 + 10.0 * lz3

	# ------------------------------------------------------------------
	# STEP 4: Bilinear interpolation using faded weights
	# ------------------------------------------------------------------
	# First interpolate horizontally (along x) for the bottom and top edges,
	# then vertically (along z) between those two results. This is standard
	# bilinear interpolation but with the smooth fade weights instead of
	# raw fractional coordinates.
	var ix0: float = dot_bl + (dot_br - dot_bl) * fade_x  # bottom edge lerp
	var ix1: float = dot_tl + (dot_tr - dot_tl) * fade_x  # top edge lerp

	return ix0 + (ix1 - ix0) * fade_z  # vertical lerp -> final noise value
