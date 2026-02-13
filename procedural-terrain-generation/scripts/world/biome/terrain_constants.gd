class_name TerrainConstants
extends RefCounted

const GAME_SEED: int = 732647346203746

const SEA_LEVEL:  float = 0.0
const MIN_HEIGHT: float = -64.0
const MAX_HEIGHT: float = 128.0

const SNOW_START_HEIGHT: float = 60.0
const SNOW_FULL_HEIGHT:  float = 80.0

const UNDERWATER_DEPTH_SCALE: float = 40.0
const UNDERWATER_MAX_DARKNESS: float = 0.6

enum Biome {
	OCEAN,
	BEACH,
	DESERT,
	PLAINS,
	FOREST,
	JUNGLE,
	HILLS,
	MOUNTAINS,
	TUNDRA,
	SNOW_PEAKS,
}

enum TempCategory {
	OCEAN,
	COLD,
	MEDIUM,
	WARM,
}

const BIOME_TEMPERATURES: Dictionary = {
	Biome.OCEAN:      TempCategory.OCEAN,
	Biome.BEACH:      TempCategory.MEDIUM,
	Biome.DESERT:     TempCategory.WARM,
	Biome.PLAINS:     TempCategory.MEDIUM,
	Biome.FOREST:     TempCategory.MEDIUM,
	Biome.JUNGLE:     TempCategory.WARM,
	Biome.HILLS:      TempCategory.MEDIUM,
	Biome.MOUNTAINS:  TempCategory.MEDIUM,
	Biome.TUNDRA:     TempCategory.COLD,
	Biome.SNOW_PEAKS: TempCategory.COLD,
}

# base = base height, variation = height noise amplitude
const BIOME_PARAMS: Dictionary = {
	Biome.OCEAN:       { "base": -30.0, "variation": 8.0 },
	Biome.BEACH:       { "base": 2.0,   "variation": 2.0 },
	Biome.DESERT:      { "base": 8.0,   "variation": 6.0 },
	Biome.PLAINS:      { "base": 6.0,   "variation": 4.0 },
	Biome.FOREST:      { "base": 10.0,  "variation": 8.0 },
	Biome.JUNGLE:      { "base": 12.0,  "variation": 10.0 },
	Biome.HILLS:       { "base": 25.0,  "variation": 18.0 },
	Biome.MOUNTAINS:   { "base": 50.0,  "variation": 40.0 },
	Biome.TUNDRA:      { "base": 8.0,   "variation": 5.0 },
	Biome.SNOW_PEAKS:  { "base": 70.0,  "variation": 50.0 },
}

const BIOME_COLORS: Dictionary = {
	Biome.OCEAN:       Color(0.1, 0.3, 0.6),
	Biome.BEACH:       Color(0.9, 0.85, 0.6),
	Biome.DESERT:      Color(0.94, 0.87, 0.5),
	Biome.PLAINS:      Color(0.3, 0.65, 0.2),
	Biome.FOREST:      Color(0.15, 0.5, 0.15),
	Biome.JUNGLE:      Color(0.1, 0.55, 0.1),
	Biome.HILLS:       Color(0.4, 0.55, 0.3),
	Biome.MOUNTAINS:   Color(0.5, 0.48, 0.45),
	Biome.TUNDRA:      Color(0.75, 0.8, 0.75),
	Biome.SNOW_PEAKS:  Color(0.95, 0.97, 1.0),
}

const BIOME_NAMES: Dictionary = {
	Biome.OCEAN:       "Ocean",
	Biome.BEACH:       "Beach",
	Biome.DESERT:      "Desert",
	Biome.PLAINS:      "Plains",
	Biome.FOREST:      "Forest",
	Biome.JUNGLE:      "Jungle",
	Biome.HILLS:       "Hills",
	Biome.MOUNTAINS:   "Mountains",
	Biome.TUNDRA:      "Tundra",
	Biome.SNOW_PEAKS:  "Snow Peaks",
}
