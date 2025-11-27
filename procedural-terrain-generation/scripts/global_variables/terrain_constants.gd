extends Node

## Global terrain configuration constants and enums
## Autoloaded as TerrainConstants

# ============================================================================
# HEIGHT CONSTANTS
# ============================================================================

const MIN_HEIGHT: int = -128
const MAX_HEIGHT: int = 128

const DEEP_OCEAN_FLOOR: int = -128
const OCEAN_FLOOR:      int = -48
const BEACH_FLOOR:      int = 0
const HILL_FLOOR:       int = 24
const MOUNTAINS_FLOOR:  int = 48
const MOUNTAINS_PEAK:   int = 128

# ============================================================================
# ENUMS
# ============================================================================

enum ClimateZone {
	TROPICAL  = 0,
	TEMPERATE = 1,
	COLD      = 2,
	FROZEN    = 3
}

enum BiomeType {
	# Ocean biomes
	OCEAN         = 0,
	DEEP_OCEAN    = 1,
	FROZEN_OCEAN  = 2,
	WARM_OCEAN    = 3,
	# Land biomes
	DESERT        = 4,
	PLAINS        = 5,
	HILLS         = 6,
	MOUNTAINS     = 7,
	JUNGLE        = 8,
	FROZEN_PLAINS = 9,
	FROZEN_PEAKS  = 10,
	# Special biomes
	BEACH         = 11
}

# ============================================================================
# BIOME PROPERTIES
# ============================================================================

const BIOME_COLORS: Dictionary = {
	BiomeType.OCEAN:          Color(0.1, 0.3, 0.7),
	BiomeType.DEEP_OCEAN:     Color(0.05, 0.15, 0.5),
	BiomeType.FROZEN_OCEAN:   Color(0.4, 0.6, 0.8),
	BiomeType.WARM_OCEAN:     Color(0.15, 0.5, 0.7),
	BiomeType.DESERT:         Color(0.94, 0.87, 0.63),
	BiomeType.PLAINS:         Color(0.177, 0.57, 0.196),
	BiomeType.HILLS:          Color(0.3, 0.6, 0.3),
	BiomeType.MOUNTAINS:      Color(0.5, 0.48, 0.45),
	BiomeType.JUNGLE:         Color(0.1, 0.5, 0.1),
	BiomeType.FROZEN_PLAINS:  Color(0.9, 0.95, 1.0),
	BiomeType.FROZEN_PEAKS:   Color(0.95, 0.97, 1.0),
	BiomeType.BEACH:          Color(0.85, 0.8, 0.6)
}

const GRASS_DENSITY: Dictionary = {
	BiomeType.OCEAN:          0.0,
	BiomeType.DEEP_OCEAN:     0.0,
	BiomeType.FROZEN_OCEAN:   0.0,
	BiomeType.WARM_OCEAN:     0.0,
	BiomeType.DESERT:         0.0,
	BiomeType.PLAINS:         3.5,
	BiomeType.HILLS:          2.8,
	BiomeType.MOUNTAINS:      0.8,
	BiomeType.JUNGLE:         4.0,
	BiomeType.FROZEN_PLAINS:  0.5,
	BiomeType.FROZEN_PEAKS:   0.0,
	BiomeType.BEACH:          0.2
}

# ============================================================================
# STRING REPRESENTATIONS
# ============================================================================

const BIOME_TYPE_STRING: Dictionary = {
	BiomeType.OCEAN:          "Ocean",
	BiomeType.DEEP_OCEAN:     "Deep Ocean",
	BiomeType.FROZEN_OCEAN:   "Frozen Ocean",
	BiomeType.WARM_OCEAN:     "Warm Ocean",
	BiomeType.DESERT:         "Desert",
	BiomeType.PLAINS:         "Plains",
	BiomeType.HILLS:          "Hills",
	BiomeType.MOUNTAINS:      "Mountains",
	BiomeType.JUNGLE:         "Jungle",
	BiomeType.FROZEN_PLAINS:  "FrozenPlains",
	BiomeType.FROZEN_PEAKS:   "FrozenPeaks",
	BiomeType.BEACH:          "Beach"
}

const CLIMATE_ZONE_STRING: Dictionary = {
	ClimateZone.TROPICAL:  "Tropical",
	ClimateZone.TEMPERATE: "Temperate",
	ClimateZone.COLD:      "Cold",
	ClimateZone.FROZEN:    "Frozen"
}
