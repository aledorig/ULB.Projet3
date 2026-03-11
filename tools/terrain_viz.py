#!/usr/bin/env python3
"""
Terrain generation pipeline visualizer.

Exact Python port of the GDScript noise classes:
  - GodotRNG     → Godot 4's RandomNumberGenerator (PCG32)
  - PerlinNoise  → scripts/world/gen/noise/perlin_noise.gd
  - OctaveNoise  → scripts/world/gen/noise/octave_noise.gd
  - SimplexNoise → scripts/world/gen/noise/simplex_noise.gd
  - TerrainGenerator (height + climate) → terrain_generator.gd

Outputs one PNG per pipeline stage into --out-dir (default: tools/terrain_viz/).

Usage:
    python tools/terrain_viz.py
    python tools/terrain_viz.py --seed 1234 --size 512 --world-span 12000 --octaves 6
    python tools/terrain_viz.py --out-dir /tmp/viz

Requirements: numpy, Pillow  (pip install numpy Pillow)
"""

import argparse
import os
import numpy as np
from PIL import Image

# ── Godot PCG32 RNG ───────────────────────────────────────────────────────────

class GodotRNG:
	"""
	Exact replica of Godot 4's RandomNumberGenerator.
	Uses PCG32 (64-bit state, 32-bit output, XSH-RR variant).
	rng.seed = value  →  GodotRNG(value)
	"""
	_MUL = 6364136223846793005
	_INC = 1442695040888963407	# PCG_DEFAULT_INCREMENT_64
	_M64 = 0xFFFFFFFFFFFFFFFF
	_M32 = 0xFFFFFFFF

	def __init__(self, seed: int):
		self.state = int(seed) & self._M64

	def _rand(self) -> int:
		old = self.state
		self.state = (old * self._MUL + self._INC) & self._M64
		xsh = int(((old >> 18) ^ old) >> 27) & self._M32
		rot = int(old >> 59)
		return int(((xsh >> rot) | (xsh << ((-rot) & 31))) & self._M32)

	def randf(self) -> float:
		return self._rand() / 4294967295.0	# divide by UINT32_MAX

	def randi_range(self, lo: int, hi: int) -> int:
		if lo == hi:
			return lo
		return lo + self._rand() % (hi - lo + 1)


# ── PerlinNoise ───────────────────────────────────────────────────────────────

_PGRAD_X = np.array([1.,-1., 1.,-1., 1.,-1., 1.,-1., 0., 0., 0., 0., 1., 0.,-1., 0.], dtype=np.float64)
_PGRAD_Z = np.array([0., 0., 0., 0., 1., 1.,-1.,-1., 1., 1.,-1.,-1., 0., 1., 0.,-1.], dtype=np.float64)


class PerlinNoise:
	"""Exact port of perlin_noise.gd."""

	def __init__(self, rng: GodotRNG):
		self.x_offset = rng.randf() * 256.0
		self.z_offset = rng.randf() * 256.0
		p = list(range(256))
		for i in range(256):
			j = rng.randi_range(i, 255)
			p[i], p[j] = p[j], p[i]
		# doubled table: perm[i+256] = perm[i]
		self._perm = np.array(p + p, dtype=np.int64)

	def fill_grid(self, out: np.ndarray,
	              x_off: float, z_off: float,
	              x_size: int, z_size: int,
	              x_scale: float, z_scale: float,
	              noise_scale: float) -> None:
		"""
		Vectorized populate_noise_array (Z-outer, X-inner, row-major).
		`noise_scale` matches the GDScript parameter — inv_scale = 1/noise_scale
		is applied to the result before adding into `out`.
		"""
		inv_scale = 1.0 / noise_scale
		perm = self._perm

		gz = np.arange(z_size, dtype=np.float64)
		gx = np.arange(x_size, dtype=np.float64)
		rz = z_off + gz * z_scale + self.z_offset	# (z_size,)
		rx = x_off + gx * x_scale + self.x_offset	# (x_size,)

		zi = np.floor(rz).astype(np.int64); lz = rz - zi; z0 = zi & 255
		xi = np.floor(rx).astype(np.int64); lx = rx - xi; x0 = xi & 255

		fz = lz**3 * (lz * (lz * 6. - 15.) + 10.)
		fx = lx**3 * (lx * (lx * 6. - 15.) + 10.)

		# broadcast to (z_size, x_size)
		z0 = z0[:, None];  lz = lz[:, None];  fz = fz[:, None]
		x0 = x0[None, :];  lx = lx[None, :];  fx = fx[None, :]

		a  = perm[x0]			# (1, x_size)
		b  = perm[x0 + 1]		# (1, x_size)  — x0+1 ≤ 256, perm is doubled
		aa = perm[a] + z0		# (z_size, x_size)
		ba = perm[b] + z0

		def grad(idx, dx, dz):
			gi = perm[idx] & 15
			return _PGRAD_X[gi] * dx + _PGRAD_Z[gi] * dz

		d00 = grad(aa,     lx,       lz      )
		d10 = grad(ba,     lx - 1.0, lz      )
		d01 = grad(aa + 1, lx,       lz - 1.0)
		d11 = grad(ba + 1, lx - 1.0, lz - 1.0)

		ix0 = d00 + (d10 - d00) * fx
		ix1 = d01 + (d11 - d01) * fx
		out += ((ix0 + (ix1 - ix0) * fz) * inv_scale).ravel()


# ── OctaveNoise ───────────────────────────────────────────────────────────────

class OctaveNoise:
	"""Exact port of octave_noise.gd."""

	def __init__(self, rng: GodotRNG, octaves: int):
		self.generators = [PerlinNoise(rng) for _ in range(octaves)]
		self.octave_count = octaves

	def generate(self, x_off: float, z_off: float,
	             x_size: int, z_size: int,
	             x_scale: float, z_scale: float,
	             max_octaves: int = -1) -> np.ndarray:
		"""
		Port of generate_octaves. Returns flat float64 array (z_size * x_size,).
		Calling convention matches get_vertex_data_batch:
		  x_off   = origin_x / spacing
		  x_scale = spacing * FREQ
		"""
		n = self.octave_count if max_octaves < 0 else min(max_octaves, self.octave_count)
		out = np.zeros(x_size * z_size, dtype=np.float64)
		freq = 1.0
		amp  = 1.0
		for j in range(n):
			self.generators[j].fill_grid(
				out,
				x_off * freq * x_scale, z_off * freq * z_scale,
				x_size, z_size,
				x_scale * freq, z_scale * freq,
				1.0 / amp,	# noise_scale → inv_scale = amp inside fill_grid
			)
			freq *= 2.0
			amp  *= 0.5
		return out


# ── SimplexNoise ──────────────────────────────────────────────────────────────

_SGRAD_X = np.array([1.,-1., 1.,-1., 1.,-1., 1.,-1., 0., 0., 0., 0.], dtype=np.float64)
_SGRAD_Z = np.array([1., 1.,-1.,-1., 0., 0., 0., 0., 1.,-1., 1.,-1.], dtype=np.float64)
_SQRT3   = 1.7320508075688772
_F2      = 0.5 * (_SQRT3 - 1.0)
_G2      = (3.0 - _SQRT3) / 6.0


class SimplexNoise:
	"""Exact port of simplex_noise.gd."""

	def __init__(self, rng: GodotRNG):
		self.x_offset = rng.randf() * 256.0
		self.z_offset = rng.randf() * 256.0
		_ = rng.randf()		# third randf() advances rng (unused in gd)
		p = list(range(256))
		for i in range(256):
			j = rng.randi_range(i, 255)
			p[i], p[j] = p[j], p[i]
		self._perm = np.array(p + p, dtype=np.int64)

	def add_to_grid(self, out: np.ndarray,
	                x_off: float, z_off: float,
	                x_size: int, z_size: int,
	                x_scale: float, z_scale: float,
	                amplitude: float) -> None:
		"""Vectorized port of SimplexNoise.add."""
		perm = self._perm

		gz = np.arange(z_size, dtype=np.float64)
		gx = np.arange(x_size, dtype=np.float64)
		# GDScript: d0 = (z_off + gz) * z_scale + z_offset
		d0 = (z_off + gz) * z_scale + self.z_offset	# (z_size,)
		d1 = (x_off + gx) * x_scale + self.x_offset	# (x_size,)

		d0 = d0[:, None]	# (z_size, 1)
		d1 = d1[None, :]	# (1, x_size)

		s  = (d1 + d0) * _F2
		i  = np.floor(d1 + s).astype(np.int64)
		j  = np.floor(d0 + s).astype(np.int64)
		t  = (i + j).astype(np.float64) * _G2
		x0 = d1 - (i.astype(np.float64) - t)
		z0 = d0 - (j.astype(np.float64) - t)

		i1 = np.where(x0 > z0, np.int64(1), np.int64(0))
		j1 = 1 - i1

		x1 = x0 - i1.astype(np.float64) + _G2
		z1 = z0 - j1.astype(np.float64) + _G2
		x2 = x0 - 1.0 + 2.0 * _G2
		z2 = z0 - 1.0 + 2.0 * _G2

		ii = i & 255
		jj = j & 255

		# perm lookups — all indices stay within 0..511
		gi0 = perm[ii       + perm[jj      ]] % 12
		gi1 = perm[(ii + i1) + perm[(jj + j1)]] % 12
		gi2 = perm[(ii + 1) + perm[(jj + 1)]] % 12

		def corner(gi, cx, cz):
			tc = 0.5 - cx**2 - cz**2
			c  = tc**2 * tc**2 * (_SGRAD_X[gi] * cx + _SGRAD_Z[gi] * cz)
			return np.where(tc < 0.0, 0.0, c)

		result = 70.0 * (corner(gi0, x0, z0) + corner(gi1, x1, z1) + corner(gi2, x2, z2))
		out += (result * amplitude).ravel()


# ── TerrainConfig constants ───────────────────────────────────────────────────

class TC:
	SEA_LEVEL       = 0.0
	OCEAN_BASE      = -75.0
	LAND_BASE       = 12.0
	MIN_AMPLITUDE   = 52.5
	MAX_AMPLITUDE   = 750.0
	SURFACE_AMP     = 4.5
	ROUGHNESS_AMP   = 60.0
	ROUGHNESS_ALT_LOW  = 30.0
	ROUGHNESS_ALT_HIGH = 150.0
	INLAND_BOOST    = 75.0

	COAST_MAX          = 12.0
	DEEP_OCEAN_OFFSET  = 30.0
	HIGHLANDS_MIN      = 90.0
	MOUNTAINS_MIN      = 180.0
	HIGH_PEAKS_MIN     = 300.0

	TUNDRA_TEMP   = -0.2
	COLD_TEMP     = -0.3
	HOT_TEMP      =  0.4
	JUNGLE_MOIST  = -0.1
	FOREST_MOIST  =  0.1

	CONTINENT_FREQ   = 0.0004
	PEAKS_FREQ       = 0.0012
	TEMPERATURE_FREQ = 0.0015
	MOISTURE_FREQ    = 0.0012
	HEIGHT_FREQ      = 0.0005
	DEPTH_FREQ       = 0.0008
	SURFACE_FREQ     = 0.012
	ROUGHNESS_FREQ   = 0.007

	SNOW_HEIGHT    = 180.0
	SNOW_BLEND_RANGE = 45.0
	BEACH_HEIGHT   = 9.0
	ALT_ROCK_LOW   = 60.0
	ALT_ROCK_HIGH  = 135.0
	ROCK_SLOPE_START = 0.55
	ROCK_SLOPE_END   = 0.35


# ── TerrainGenerator (vectorized) ────────────────────────────────────────────

def _smoothstep(e0, e1, x):
	t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
	return t * t * (3.0 - 2.0 * t)


def _shape_noise(n):
	return np.abs(n) ** 1.8 * np.sign(n)


class TerrainGenerator:
	"""
	Vectorized port of terrain_generator.gd.
	Initialization order of RNG consumers must exactly match the GDScript _init.
	"""

	def __init__(self, seed: int, octaves: int = 6):
		rng = GodotRNG(seed)
		# same construction order as GDScript _init
		self.height_noise          = OctaveNoise(rng, octaves)
		self.depth_noise           = OctaveNoise(rng, octaves)
		self.surface_noise         = SimplexNoise(rng)
		self.continentalness_noise = OctaveNoise(rng, octaves)
		self.peaks_noise           = OctaveNoise(rng, octaves)
		self.temperature_noise     = SimplexNoise(rng)
		self.moisture_noise        = SimplexNoise(rng)
		self.roughness_noise       = OctaveNoise(rng, octaves)

	def _grid_args(self, origin_x, origin_z, size, spacing):
		"""Helper: returns (x_off, z_off, x_size, z_size) for a square grid."""
		inv = 1.0 / spacing
		return origin_x * inv, origin_z * inv, size, size

	def generate_all(self, origin_x: float, origin_z: float,
	                 size: int, spacing: float) -> dict:
		"""
		Generate all noise grids for a SIZE×SIZE region starting at (origin_x, origin_z).
		Returns a dict of named 2D numpy arrays shaped (size, size).
		"""
		x_off, z_off, W, H = self._grid_args(origin_x, origin_z, size, spacing)

		def octave(noise, freq):
			return noise.generate(x_off, z_off, W, H, spacing * freq, spacing * freq).reshape(H, W)

		def simplex(noise, freq):
			out = np.zeros(W * H, dtype=np.float64)
			noise.add_to_grid(out, x_off, z_off, W, H, spacing * freq, spacing * freq, 1.0)
			return out.reshape(H, W)

		cont    = octave(self.continentalness_noise, TC.CONTINENT_FREQ)
		peaks   = octave(self.peaks_noise,           TC.PEAKS_FREQ)
		h_noise = octave(self.height_noise,          TC.HEIGHT_FREQ)
		depth   = octave(self.depth_noise,           TC.DEPTH_FREQ)
		surface = simplex(self.surface_noise,        TC.SURFACE_FREQ)
		surface  *= TC.SURFACE_AMP / 70.0
		roughness = octave(self.roughness_noise,     TC.ROUGHNESS_FREQ)
		temp    = simplex(self.temperature_noise,    TC.TEMPERATURE_FREQ)
		moist   = simplex(self.moisture_noise,       TC.MOISTURE_FREQ)

		base       = _compute_base(cont)
		amplitude  = _compute_amplitude(cont, peaks)
		shaped     = _shape_noise(h_noise)
		base_h     = base + (shaped * amplitude * (1.0 + depth * 0.6)) + surface
		alt_factor = _smoothstep(TC.ROUGHNESS_ALT_LOW, TC.ROUGHNESS_ALT_HIGH, base_h)
		height     = base_h + roughness * TC.ROUGHNESS_AMP * alt_factor

		return {
			"continentalness": cont,
			"peaks":           peaks,
			"height_noise":    h_noise,
			"depth":           depth,
			"temperature":     temp,
			"moisture":        moist,
			"base_elevation":  base,
			"amplitude":       amplitude,
			"shaped_noise":    shaped,
			"base_height":     base_h,
			"final_height":    height,
		}


def _compute_base(cont):
	sea_land     = np.interp(_smoothstep(-0.5, -0.15, cont), [0, 1], [TC.OCEAN_BASE, TC.LAND_BASE])
	inland_boost = _smoothstep(-0.15, 0.2, cont) * TC.INLAND_BOOST
	return sea_land + inland_boost


def _compute_amplitude(cont, peaks):
	land_factor = _smoothstep(-0.5, -0.15, cont)
	return (np.interp(_smoothstep(-0.8, 0.2, peaks), [0, 1], [TC.MIN_AMPLITUDE, TC.MAX_AMPLITUDE])
	        * np.interp(land_factor, [0, 1], [0.3, 1.0]))


def get_biome(height, temp, moist):
	"""Returns a string label per pixel. Operates element-wise via np.select."""
	h = height; t = temp; m = moist
	# np.select evaluates in order — mirrors GDScript if/elif chain
	# (HIGH_PEAKS before MOUNTAINS before HIGHLANDS, temp check within each)
	conds2 = [
		h <  TC.SEA_LEVEL - TC.DEEP_OCEAN_OFFSET,
		h <  TC.SEA_LEVEL,
		h <  TC.COAST_MAX,
		(h >= TC.HIGH_PEAKS_MIN) & (t < TC.TUNDRA_TEMP),
		h >= TC.HIGH_PEAKS_MIN,
		(h >= TC.MOUNTAINS_MIN)  & (t < TC.TUNDRA_TEMP),
		h >= TC.MOUNTAINS_MIN,
		(h >= TC.HIGHLANDS_MIN)  & (t < TC.TUNDRA_TEMP),
		h >= TC.HIGHLANDS_MIN,
		(t > TC.HOT_TEMP)        & (m < TC.JUNGLE_MOIST),
		t > TC.HOT_TEMP,
		t < TC.COLD_TEMP,
		m > TC.FOREST_MOIST,
	]
	choices2 = [
		"Deep Ocean", "Ocean", "Coast",
		"Snow Peaks", "High Peaks",
		"Snow Mountains", "Mountains",
		"Tundra Hills", "Highlands",
		"Desert", "Jungle", "Tundra", "Forest",
	]
	return np.select(conds2, choices2, default="Plains")


# ── Biome colour palette ──────────────────────────────────────────────────────

BIOME_COLORS = {
	"Deep Ocean":      (  0,  30, 100),
	"Ocean":           ( 10,  80, 180),
	"Coast":           (220, 210, 150),
	"Plains":          (120, 180,  60),
	"Forest":          ( 30, 110,  30),
	"Jungle":          ( 10, 140,  20),
	"Desert":          (220, 190,  90),
	"Tundra":          (160, 200, 200),
	"Highlands":       ( 90, 140,  60),
	"Tundra Hills":    (160, 190, 170),
	"Mountains":       (130, 110,  90),
	"Snow Mountains":  (200, 210, 230),
	"High Peaks":      (100,  80,  70),
	"Snow Peaks":      (240, 245, 255),
}


# ── Image helpers ─────────────────────────────────────────────────────────────

def _norm01(arr):
	lo, hi = arr.min(), arr.max()
	if hi == lo:
		return np.zeros_like(arr)
	return (arr - lo) / (hi - lo)


def save_grayscale(arr, path):
	img = Image.fromarray((_norm01(arr) * 255).astype(np.uint8), mode="L")
	img.save(path)
	print(f"  {path}")


def save_rgb(r, g, b, path):
	data = np.stack([
		(_norm01(r) * 255).astype(np.uint8),
		(_norm01(g) * 255).astype(np.uint8),
		(_norm01(b) * 255).astype(np.uint8),
	], axis=-1)
	Image.fromarray(data, mode="RGB").save(path)
	print(f"  {path}")


def save_heightmap(arr, path):
	"""Height visualized with a perceptual gradient (deep blue → white)."""
	h01 = _norm01(arr)
	sea_mask = arr < TC.SEA_LEVEL
	sea_frac = np.clip((arr - arr.min()) / max(-arr.min(), 1e-6), 0, 1) * sea_mask
	land_frac = np.where(sea_mask, 0.0, h01)

	# deep ocean: dark blue → light blue; land: dark green → white
	r = np.where(sea_mask, (sea_frac * 40).astype(int),
	             (land_frac * 255).astype(int)).astype(np.uint8)
	g = np.where(sea_mask, (sea_frac * 80).astype(int),
	             (land_frac * 255).astype(int)).astype(np.uint8)
	b = np.where(sea_mask, (40 + sea_frac * 180).astype(int),
	             (land_frac * 255).astype(int)).astype(np.uint8)
	Image.fromarray(np.stack([r, g, b], axis=-1), mode="RGB").save(path)
	print(f"  {path}")


def save_biome_map(height, temp, moist, path):
	biomes = get_biome(height, temp, moist)
	size = height.shape[0]
	rgb = np.zeros((size, size, 3), dtype=np.uint8)
	for name, color in BIOME_COLORS.items():
		mask = biomes == name
		for c, v in enumerate(color):
			rgb[:, :, c][mask] = v
	Image.fromarray(rgb, mode="RGB").save(path)
	print(f"  {path}")


def save_terrain_shaded(height, temp_raw, moist_raw, path):
	"""Approximate the shader: texture zones by altitude + slope proxy."""
	h = height
	t = temp_raw
	m = moist_raw

	rgb = np.zeros((*h.shape, 3), dtype=np.float32)

	# base colour by altitude
	# deep water
	mask_deep = h < TC.SEA_LEVEL - TC.DEEP_OCEAN_OFFSET
	rgb[mask_deep] = [0.02, 0.05, 0.35]

	# shallow water
	mask_ocean = (h >= TC.SEA_LEVEL - TC.DEEP_OCEAN_OFFSET) & (h < TC.SEA_LEVEL)
	rgb[mask_ocean] = [0.05, 0.20, 0.65]

	# beach / coast
	mask_coast = (h >= TC.SEA_LEVEL) & (h < TC.BEACH_HEIGHT)
	rgb[mask_coast] = [0.85, 0.78, 0.52]

	# grass / low land
	mask_grass = (h >= TC.BEACH_HEIGHT) & (h < TC.ALT_ROCK_LOW)
	hot  = t > TC.HOT_TEMP
	cold = t < TC.COLD_TEMP
	wet  = m > TC.FOREST_MOIST
	# desert / jungle / tundra / forest / plains
	rgb[mask_grass & hot & (m < TC.JUNGLE_MOIST)] = [0.80, 0.68, 0.30]	# desert
	rgb[mask_grass & hot & (m >= TC.JUNGLE_MOIST)] = [0.10, 0.45, 0.10]	# jungle
	rgb[mask_grass & cold] = [0.70, 0.80, 0.75]				# tundra
	rgb[mask_grass & ~hot & ~cold & wet] = [0.15, 0.45, 0.10]	# forest
	rgb[mask_grass & ~hot & ~cold & ~wet] = [0.45, 0.65, 0.20]	# plains

	# mid rock
	mask_rock = (h >= TC.ALT_ROCK_LOW) & (h < TC.MOUNTAINS_MIN)
	rgb[mask_rock] = [0.48, 0.42, 0.36]

	# high rock / mountains
	mask_mount = (h >= TC.MOUNTAINS_MIN) & (h < TC.SNOW_HEIGHT)
	rgb[mask_mount] = [0.38, 0.33, 0.28]

	# snow
	mask_snow = h >= TC.SNOW_HEIGHT
	rgb[mask_snow] = [0.92, 0.94, 0.98]

	# add slight altitude shading
	alt_shade = np.clip(_norm01(h) * 0.4 + 0.6, 0, 1)[:, :, None]
	rgb = np.clip(rgb * alt_shade, 0, 1)

	Image.fromarray((rgb * 255).astype(np.uint8), mode="RGB").save(path)
	print(f"  {path}")


# ── Main ─────────────────────────────────────────────────────────────────────

def main():
	p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
	p.add_argument("--seed",       type=int,   default=12345,  help="World seed (default: 12345)")
	p.add_argument("--size",       type=int,   default=512,    help="Image resolution in pixels (default: 512)")
	p.add_argument("--world-span", type=float, default=10000,  help="World units covered (default: 10000)")
	p.add_argument("--octaves",    type=int,   default=6,      help="Noise octaves (default: 6)")
	p.add_argument("--out-dir",    type=str,   default=None,   help="Output directory (default: tools/terrain_viz/)")
	args = p.parse_args()

	if args.out_dir is None:
		script_dir = os.path.dirname(os.path.abspath(__file__))
		out_dir = os.path.join(script_dir, "terrain_viz")
	else:
		out_dir = args.out_dir
	os.makedirs(out_dir, exist_ok=True)

	SIZE    = args.size
	SPAN    = args.world_span
	spacing = SPAN / SIZE

	print(f"seed={args.seed}  size={SIZE}×{SIZE}  world_span={SPAN}  octaves={args.octaves}")
	print(f"output → {out_dir}/")
	print("Generating noise grids…")

	gen    = TerrainGenerator(args.seed, args.octaves)
	grids  = gen.generate_all(0.0, 0.0, SIZE, spacing)

	cont   = grids["continentalness"]
	peaks  = grids["peaks"]
	h_raw  = grids["height_noise"]
	temp   = grids["temperature"]
	moist  = grids["moisture"]
	base_e = grids["base_elevation"]
	amp    = grids["amplitude"]
	shaped = grids["shaped_noise"]
	base_h = grids["base_height"]
	height = grids["final_height"]

	print("Saving images…")

	# 1. raw noise layers (grayscale)
	save_grayscale(cont,   os.path.join(out_dir, "01_continentalness.png"))
	save_grayscale(peaks,  os.path.join(out_dir, "02_peaks.png"))
	save_grayscale(h_raw,  os.path.join(out_dir, "03_height_noise_raw.png"))
	save_grayscale(temp,   os.path.join(out_dir, "04_temperature_raw.png"))
	save_grayscale(moist,  os.path.join(out_dir, "05_moisture_raw.png"))

	# 2. climate as RGB (R=temp, G=moist, B=cont) — same as vertex colors in game
	t01 = np.clip(temp  * 0.5 + 0.5, 0, 1)
	m01 = np.clip(moist * 0.5 + 0.5, 0, 1)
	c01 = np.clip(cont  * 0.5 + 0.5, 0, 1)
	rgb_climate = np.stack([(t01 * 255).astype(np.uint8),
	                         (m01 * 255).astype(np.uint8),
	                         (c01 * 255).astype(np.uint8)], axis=-1)
	Image.fromarray(rgb_climate, mode="RGB").save(os.path.join(out_dir, "06_climate_vertex_colors.png"))
	print(f"  {os.path.join(out_dir, '06_climate_vertex_colors.png')}")

	# 3. intermediate pipeline stages
	save_heightmap(base_e, os.path.join(out_dir, "07_base_elevation.png"))
	save_grayscale(amp,    os.path.join(out_dir, "08_amplitude.png"))
	save_grayscale(shaped, os.path.join(out_dir, "09_shaped_height_noise.png"))
	save_heightmap(base_h, os.path.join(out_dir, "10_base_height_no_roughness.png"))

	# 4. final outputs
	save_heightmap(height, os.path.join(out_dir, "11_final_height.png"))
	save_biome_map(height, temp, moist, os.path.join(out_dir, "12_biome_zones.png"))
	save_terrain_shaded(height, temp, moist, os.path.join(out_dir, "13_terrain_shaded.png"))

	print("Done.")


if __name__ == "__main__":
	main()
