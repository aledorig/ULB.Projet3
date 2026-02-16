class_name TerrainConfig
extends RefCounted

# Absolute bounds
const SEA_LEVEL:       float = 0.0
const ABS_MIN_HEIGHT:  float = -96.0
const ABS_MAX_HEIGHT:  float = 524.0

# Terrain shaping
const OCEAN_BASE:      float = -75.0
const LAND_BASE:       float = 12.0
const MIN_AMPLITUDE:   float = 52.5
const MAX_AMPLITUDE:   float = 750.0
const SURFACE_AMP:     float = 4.5
const ROUGHNESS_AMP:   float = 37.5
const ROUGHNESS_ALT_LOW:  float = 45.0
const ROUGHNESS_ALT_HIGH: float = 150.0
const INLAND_BOOST:    float = 75.0

# Zone altitude thresholds
const COAST_MAX:         float = 12.0
const DEEP_OCEAN_OFFSET: float = 30.0
const HIGHLANDS_MIN:     float = 90.0
const MOUNTAINS_MIN:     float = 180.0
const HIGH_PEAKS_MIN:    float = 300.0

# Climate thresholds (raw noise values -1..1)
const TUNDRA_TEMP:   float = -0.2
const COLD_TEMP:     float = -0.3
const HOT_TEMP:      float = 0.4
const JUNGLE_MOIST:  float = -0.1
const FOREST_MOIST:  float = 0.1

# Climate thresholds (0..1 normalized)
const DESERT_TEMP:   float = 0.65
const DESERT_MOIST:  float = 0.38

# Vegetation shared
const GRASS_MIN_HEIGHT:     float = 10.0
const GRASS_MAX_HEIGHT:     float = 120.0
const MIN_NORMAL_Y:         float = 0.7
const SAMPLE_JITTER:        float = 0.85

# Grass LOD
const GRASS_LOD_CANDIDATES: Array[int] = [12000, 2400, 200]
const GRASS_LOD_GRID_RES:   Array[int] = [32, 16, 8]

# Trees
const TREE_MIN_TEMP:       float = 0.35
const TREE_MIN_HEIGHT:     float = 10.0
const TREE_MAX_HEIGHT:     float = 120.0
const TREE_CANDIDATES:     int   = 25
const TREE_DENSITY:        float = 0.4
const TREE_VARIANTS:       int   = 5
const TREE_SCALE_MIN:      float = 2.0
const TREE_SCALE_MAX:      float = 3.5
const TREE_Y_OFFSET:       float = -1.0

# Foliage
const FOLIAGE_TOTAL_TYPES:     int   = 14
const FOLIAGE_TYPES_PER_CHUNK: int   = 4
const FOLIAGE_Y_OFFSET:        float = -0.8

# Foliage LOD
const FOLIAGE_LOD_CANDIDATES: Array[int] = [150, 40, 0]

# Per-type density
const FOLIAGE_DENSITIES: Array[float] = [
	0.30, 0.25, 0.28, 0.12, 0.08,  # Bush, BushFlowers, Fern, Mushroom, Laetiporus
	0.22, 0.30, 0.25, 0.30, 0.25,  # Flower3Grp, Flower3Sgl, Flower4Grp, Flower4Sgl, Plant7
	0.10, 0.20, 0.35, 0.35         # Plant7Big, Plant1, Clover1, Clover2
]

# Visibility ranges
const VIS_RANGE_GRASS:   float = 400.0
const VIS_RANGE_TREE:    float = 600.0
const VIS_RANGE_FOLIAGE: float = 300.0

# Noise frequencies
const CONTINENT_FREQ:   float = 0.0004
const PEAKS_FREQ:       float = 0.0012
const TEMPERATURE_FREQ: float = 0.0015
const MOISTURE_FREQ:    float = 0.0012
const HEIGHT_FREQ:      float = 0.0005
const DEPTH_FREQ:       float = 0.0008
const SURFACE_FREQ:     float = 0.012
const ROUGHNESS_FREQ:   float = 0.005

# Terrain material
const TERRAIN_SHADER_PATH: String = "res://shaders/environment/terrain.gdshader"
const GRASS_TEXTURE_PATH:  String = "res://assets/textures/grass.png"
const SAND_TEXTURE_PATH:   String = "res://assets/textures/sand.png"
const ROCK_TEXTURE_PATH:   String = "res://assets/textures/rock.png"
const SNOW_TEXTURE_PATH:   String = "res://assets/textures/snow.png"
const TEXTURE_SCALE:       float  = 20.0
const TEXTURE_STRENGTH:    float  = 0.65

# Shader-facing
const SNOW_HEIGHT:      float = 180.0
const SNOW_BLEND_RANGE: float = 45.0
const BEACH_HEIGHT:     float = 9.0
const ALT_ROCK_LOW:     float = 60.0
const ALT_ROCK_HIGH:    float = 135.0
const ROCK_SLOPE_START: float = 0.55
const ROCK_SLOPE_END:   float = 0.35
