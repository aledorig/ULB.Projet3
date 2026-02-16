class_name TerrainConfig
extends RefCounted

# Absolute bounds
const SEA_LEVEL:       float = 0.0
const ABS_MIN_HEIGHT:  float = -96.0
const ABS_MAX_HEIGHT:  float = 524.0

# Terrain shaping (TerrainGenerator)
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

# Vegetation height/slope
const GRASS_MIN_HEIGHT:     float = 10.0
const GRASS_MAX_HEIGHT:     float = 120.0
const MIN_NORMAL_Y:         float = 0.7

# Trees (Pine_1..5)
const TREE_MIN_TEMP:       float = 0.35
const TREE_MIN_HEIGHT:     float = 10.0
const TREE_MAX_HEIGHT:     float = 120.0
const TREE_CANDIDATES:     int   = 25
const TREE_DENSITY:        float = 0.4
const TREE_VARIANTS:       int   = 5
const TREE_SCALE_MIN:      float = 2.0
const TREE_SCALE_MAX:      float = 3.5
const TREE_Y_OFFSET:       float = -1.0

# Foliage (Bush, Fern, Mushroom, Flower, Plant_7, Plant_7_Big)
const FOLIAGE_TOTAL_TYPES:     int   = 6
const FOLIAGE_TYPES_PER_CHUNK: int  = 2
const FOLIAGE_CANDIDATES:      int   = 60
const FOLIAGE_Y_OFFSET:        float = -0.8

# Visibility ranges (GPU distance culling)
const VIS_RANGE_TREE:    float = 600.0
const VIS_RANGE_FOLIAGE: float = 300.0

# Shader-facing (pushed to terrain.gdshader via TerrainMaterialManager)
const SNOW_HEIGHT:      float = 180.0
const SNOW_BLEND_RANGE: float = 45.0
const BEACH_HEIGHT:     float = 9.0
const ALT_ROCK_LOW:     float = 60.0
const ALT_ROCK_HIGH:    float = 135.0
const ROCK_SLOPE_START: float = 0.55
const ROCK_SLOPE_END:   float = 0.35
