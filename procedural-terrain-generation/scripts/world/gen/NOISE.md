# Noise System

Three generators form a hierarchy: **PerlinNoise** (single octave) → **OctaveNoise** (FBM wrapper) → **SimplexNoise** (triangle grid).

All three are seeded from a single `RandomNumberGenerator` sequence in `TerrainGenerator._init()`,
so the same world seed always produces the same terrain.

## PerlinNoise

2D improved Perlin noise. Each instance holds:

- A **permutation table** (512 entries: 256 shuffled values mirrored) — the hash function.
- **x/z offsets** — random coordinate shift so each octave samples a different region.
- **16 gradient directions** (`GRAD_X`/`GRAD_Z`) — Minecraft uses a fixed set rather than
  arbitrary unit vectors.

### Algorithm

1. **Floor** the input coordinates to get integer cell `(x0, z0)`, fractional `(lx, lz)`.
2. **Quintic fade**: `f(t) = t³(t(6t − 15) + 10)` — Ken Perlin's improved curve
   (C² continuous, eliminates the second-derivative discontinuities of the original cubic).
3. **Hash** the 4 corners via the permutation table to select gradient indices.
4. **Dot product** between each corner's gradient vector and the distance vector to the sample point.
5. **Bilinear interpolation** using the faded values.

### Batch path (`populate_noise_array`)

Used by `OctaveNoise.generate_octaves()` for entire chunk grids. Key details:

- **Accumulates** into the output array (`out[idx] += result * inv_scale`) so multiple
  octaves can layer on top of each other.
- **Z-outer, X-inner** loop order matches `TerrainGenerator`'s row-major indexing
  (`idx = z * width + x`). Transposing this causes chunk boundary mismatches.

## OctaveNoise

Fractal Brownian Motion (FBM) that layers N `PerlinNoise` instances.

Each octave doubles in frequency and halves in amplitude:

```text
result = Σ perlin[i](x × freq, z × freq) × amplitude
freq  ×= 2.0
amp   ×= 0.5
```

We use **standard FBM** (amplitude sum ≈ 1.875 for 4 octaves) rather than Minecraft's inverted
convention (`d3 /= 2.0` with `1/d3` amplitude, sum ≈ 15). Our terrain parameters
(`base_height`, `variation`) are tuned for standard FBM range.

### Batch path (`generate_octaves`)

Zeros the output array, then calls `PerlinNoise.populate_noise_array()` for each octave.
The `noise_scale` parameter is `1.0 / amplitude` so the accumulation gives the correct weight.

## SimplexNoise

2D simplex noise using a triangular grid. Advantages over Perlin: fewer multiplications (3 corners vs 4), no directional artifacts, better visual isotropy.

### Algorithm

1. **Skew** input `(x, z)` to a simplex grid using factor `F2 = (√3 − 1) / 2`.
2. **Determine** which simplex triangle the point falls in (upper vs lower).
3. **Unskew** back with factor `G2 = (3 − √3) / 6` to get offsets from each of 3 corners.
4. For each corner: compute `t = 0.5 − dx² − dz²`. If `t > 0`, contribution = `t⁴ × (gradient · offset)`.
5. **Sum** the 3 contributions, scaled by 70.0 to normalize range to approximately [-1, 1].

### RNG advancement

The constructor consumes 3 `randf()` calls from the shared RNG. This keeps the RNG sequence aligned so subsequent generators get the expected seeds.
