# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Godot 4.5 procedural terrain generation project with infinite terrain, biome system, and 6DOF ship exploration. The main scene is `scenes/main/terrain_world.tscn`.

## Running the Project

Open in Godot 4.5 and run. No build step required. Press F5 or run `terrain_world.tscn`.

## Controls

- WASD: Pitch (W/S) and Roll (A/D)
- Q/E: Yaw
- Space: Throttle up
- Left Shift: Throttle down
- F3: Toggle debug overlay

## Architecture

### Biome Generation (GenLayer Pipeline)

Minecraft 1.9-style layered biome generation in `scripts/terrain/biome/`:

1. **GenLayer** (`gen_layer.gd`) - Base class with LCG-based PRNG for deterministic generation
2. **Layer Pipeline** (`biome_generator.gd`) - Chains transformation layers:
   - `GenLayerIsland` → initial land/ocean distribution
   - `GenLayerZoom` → 2x scale with interpolation
   - `GenLayerAddIsland` → add more landmasses
   - `GenLayerClimate` → assign temperature zones (warm/medium/cold/frozen)
   - `GenLayerClimateEdge` → prevent hot/cold adjacency
   - `GenLayerBiome` → convert climate to biome IDs
   - `GenLayerBiomeEdge` → insert transition biomes at incompatible borders
   - `GenLayerShore` → add beaches at land/ocean borders
   - `GenLayerSmooth` → smooth isolated cells
3. **BiomeCache** (`biome_cache.gd`) - LRU cache for 16x16 biome chunks

### Terrain Generation Pipeline

1. **BiomeManager** (`scripts/terrain/biome/biome_manager.gd`) - Queries GenLayer pipeline with caching. Provides biome blending for smooth terrain transitions.

2. **TerrainGenerator** (`scripts/terrain/generation/terrain_generator.gd`) - Combines biome height params with FBM noise.

3. **ChunkMeshBuilder** (`scripts/terrain/generation/chunk_mesh_builder.gd`) - Builds ArrayMesh with overlap vertices for seamless normals.

4. **ChunkManager** (`scripts/terrain/management/chunk_manager.gd`) - Thread pool for async generation, LRU mesh cache, priority queue.

### Key Constants

`TerrainConstants` (`scripts/config/terrain_constants.gd`) - global class containing:
- `GAME_SEED`: World seed
- `SEA_LEVEL`, `SNOW_START_HEIGHT`, `SNOW_FULL_HEIGHT`: Height thresholds
- `UNDERWATER_DEPTH_SCALE`, `UNDERWATER_MAX_DARKNESS`: Underwater color settings
- `Biome` enum: OCEAN, BEACH, DESERT, PLAINS, FOREST, JUNGLE, MOUNTAINS, TUNDRA, SNOW_PEAKS
- `TempCategory` enum: OCEAN, COLD, MEDIUM, WARM (for biome compatibility rules)
- `BIOME_TEMPERATURES`: Maps each biome to its temperature category
- `BIOME_PARAMS`: Height parameters per biome (base height, variation)
- `BIOME_COLORS`: Vertex colors per biome

### Shaders

- `shaders/environment/sky.gdshader` - Sky gradient
- `shaders/environment/water.gdshader` - Water surface with waves and fresnel
- `shaders/ui/pixelation.gdshader` - Post-processing pixelation effect
- Terrain shader is generated in `TerrainMaterialManager` with world curvature effect

### Scene Structure

```
TerrainWorld (ChunkManager)
├── MainCamera (follows ship)
├── DirectionalLight3D
├── WorldEnvironment
├── CanvasLayer (UI)
│   ├── Label (debug overlay)
│   ├── Map
│   └── ColorRect (pixelation shader)
└── Executioner (ship)
```

## Threading Model

ChunkManager uses a thread pool (default 4 workers) with semaphore-based work distribution. Results are processed on the main thread to safely instantiate scene nodes.
