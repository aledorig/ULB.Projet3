# Biome Generation Pipeline

Biomes are generated through a chain of `GenLayer` transformations operating on integer grids.

## GenLayer base class

Each layer holds:

- **parent** — the previous layer in the chain (null for `GenLayerIsland`).
- **LCG PRNG** — a linear congruential generator seeded from the world seed + per-layer base seed.
  Uses `value × 6364136223846793005 + 1442695040888963407` (64-bit).
- **`init_chunk_seed(x, z)`** — derives a position-dependent seed so the same `(x, z)` always
  produces the same random sequence, regardless of query order.
- **`next_int(bound)`** — returns a deterministic pseudo-random int in `[0, bound)`.

The `select_mode_or_random(a, b, c, d)` helper picks the most common of 4 values,
falling back to random selection when there's no majority — used by zoom layers.

### IntCache

Object pool for `PackedInt32Array` to avoid GC pressure during generation.
Arrays are borrowed via `get_int_cache(size)` and returned in bulk via `reset()`.

## Pipeline stages

Built in `BiomeGenerator._init_layers()`. Each stage refines the grid:

### Stage 1: Land/Ocean distribution

```text
GenLayerIsland(seed=1, land_chance=10)     10% land, forced land at origin
  → GenLayerZoom(seed=2000, fuzzy=true)    2× resolution with random interpolation
  → GenLayerAddIsland(seed=1)              fill in land near existing land
  → GenLayerZoom(seed=2001)                2× resolution (mode-based)
  → GenLayerAddIsland × 3                  more land passes
```

Values: `0` = ocean, `1` = land.

### Stage 2: Climate zones

```text
GenLayerClimate(seed=2)                    assign climate categories
  → GenLayerClimateEdge(COOL_WARM)         warm(1) can't touch cold(3) → medium(2)
  → GenLayerClimateEdge(HEAT_ICE)          frozen(4) can't touch warm(1) → cold(3)
  → GenLayerZoom × 2                       increase resolution
```

Values: `0`=ocean, `1`=warm, `2`=medium, `3`=cold, `4`=frozen.

### Stage 3: Biome selection

```text
GenLayerBiome(seed=200)                    climate zones → biome IDs
  → GenLayerZoom × 2
  → GenLayerBiomeEdge(seed=1000)           insert transition biomes
```

Each climate picks from weighted arrays:

- **Warm**: Desert(×2), Plains, Jungle
- **Medium**: Forest(×2), Plains(×2), Hills, Mountains
- **Cold**: Forest, Mountains, Tundra, Hills
- **Frozen**: Tundra(×2), Snow Peaks(×2)

### Stage 4: Final refinement

```text
for i in range(biome_size=4):              4 zoom passes (16× resolution)
  GenLayerZoom(seed=1000+i)
  if i == 1:
    GenLayerShore(seed=1000)               add beaches between land and ocean

GenLayerSmooth(seed=1000)                  clean up isolated cells
```

`biome_size = 4` means 4 zoom passes = 2⁴ = 16× resolution increase.
Each increment doubles biome scale.

## Edge rules (`GenLayerBiomeEdge`)

Prevents jarring biome adjacencies:

| Center biome | Neighbor condition | Result |
|---|---|---|
| Desert | touches frozen (Tundra/Snow Peaks) | → Plains |
| Jungle | touches non-compatible biome | → Forest |
| Snow Peaks | touches warm (Desert/Jungle) | → Mountains |
| Mountains | touches lowland (Plains/Forest/Desert/Jungle/Beach/Tundra) | → Hills |
| Tundra | touches warm | → Plains or Forest (random) |
| Any | incompatible temperature neighbor | → transition biome |

The Hills biome (base=25, variation=18) serves as a gradient between flat biomes
(base 6–12) and Mountains (base=50, variation=40).

## Shore detection (`GenLayerShore`)

Uses `SHORE_RADIUS = 2` — checks a 5×5 area around each cell for ocean.
Land cells near ocean become Beach, except Mountains and Snow Peaks which stay
as cliffs.

## Caching (`BiomeCache` + `BiomeManager`)

- **BiomeCache**: LRU cache of 32×32 biome chunks. Key is a Cantor pairing of chunk coords.
  Capacity: 1024 chunks.
- **BiomeManager**: Converts world coordinates to biome-grid coordinates via `BIOME_SCALE = 4.0`
  (4 world units per biome cell). Supports blended terrain parameters via Catmull-Rom
  interpolation on a coarse grid (`BLEND_GRID_SIZE = 8.0`).

### Catmull-Rom blending

For smooth biome borders, terrain parameters (base height, variation) are sampled on a
coarse grid and interpolated with a 4×4 Catmull-Rom kernel. Colors use bilinear
interpolation instead (Catmull-Rom on colors can produce out-of-gamut artifacts).

Weight formula for parameter `t ∈ [0,1]`:

```text
w0 = −0.5t³ + t² − 0.5t
w1 =  1.5t³ − 2.5t² + 1.0
w2 = −1.5t³ + 2.0t² + 0.5t
w3 =  0.5t³ − 0.5t²
```
