extends Node

var MIN_HEIGHT = -127
var MAX_HEIGHT = 128
var DEEP_OCEAN_FLOOR = -127
var OCEAN_FLOOR = -64
var RIVER_FLOOR = -10
var BEACH_FLOOR = 0
var HILL_FLOOR = 21
var MOUNTAINS_FLOOR = 42
var MOUNTAINS_PEAK = 118

# Climate zones (continental scale)
enum ClimateZone {
	TROPICAL   = 0,
	TEMPERATE  = 1,
	COLD       = 2,
	FROZEN     = 3
}

# Expanded biome types (Minecraft-style)
enum BiomeType {
	# Ocean biomes
	OCEAN           = 0,
	DEEP_OCEAN      = 1,
	FROZEN_OCEAN    = 2,
	WARM_OCEAN      = 3,
	
	# Land biomes
	DESERT          = 4,
	PLAINS          = 5,
	HILLS           = 6,
	MOUNTAINS       = 7,
	JUNGLE          = 8,
	FROZEN_PLAINS   = 9,
	FROZEN_PEAKS    = 10,
	
	# Special
	BEACH           = 11,
	RIVER           = 12
}

# ============================================================================
# CONSTANTS
# ============================================================================

# Biome colors (for vertex coloring)
const BIOME_COLORS = {
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
	BiomeType.BEACH:          Color(0.85, 0.8, 0.6),
	BiomeType.RIVER:          Color(0.2, 0.4, 0.6)
}

# Grass density (for future grass spawning)
const GRASS_DENSITY = {
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
	BiomeType.BEACH:          0.2,
	BiomeType.RIVER:          0.0
}

const BIOME_TYPE_STRING = {
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
	BiomeType.BEACH:          "Beach",
	BiomeType.RIVER:          "River"
}

const CLIMATE_ZONE_STRING = {
	ClimateZone.TROPICAL: "Tropical",
	ClimateZone.TEMPERATE: "Temperate",
	ClimateZone.COLD: "Cold",
	ClimateZone.FROZEN: "Frozen",
	
}
