class_name NoiseDemoController
extends Node3D

# ── Static constants ──────────────────────────────────────────────────────────
const MESH_SIZE   : int   = 40
# V_SPACING chosen so the demo covers the same 2000×2000 world units as the
# Python terrain_viz script (--world-span 2000) → WORLD_SPAN/(MESH_SIZE-1)
const WORLD_SPAN  : float = 2000.0
const V_SPACING   : float = WORLD_SPAN / 39.0   # ≈ 51.28 wu/vertex
const MESH_WORLD  : float = WORLD_SPAN           # = (MESH_SIZE-1)*V_SPACING
const MAX_OCTAVES : int   = 6
const ANIM_DUR    : float = 1.8   # seconds per octave step
const GRID_Y      : float = 1.0   # lattice grid height above flat mesh (wu)

# ── Runtime parameters (editable via side panel) ──────────────────────────────
# Default freq matches TerrainConfig.HEIGHT_FREQ so Godot ↔ Python outputs match.
var _freq      : float = TerrainConfig.HEIGHT_FREQ  # 0.0005 by default
var _amp_scale : float = 1.0    # global vertical scale applied at render time
var _seed      : int   = 1010   # matches Python terrain_viz default seed

# ── Baked data ────────────────────────────────────────────────────────────────
var _gen     : TerrainGenerator
var _h_baked : Array[PackedFloat32Array]   # [0]=flat … [MAX_OCTAVES]=full FBM
var _c_baked : Array[PackedColorArray]
var _dot_data: Array   # Array of {wx, wz, h1} — cell-centre positions + oct-1 height

# ── 3-D nodes ─────────────────────────────────────────────────────────────────
var _terrain_inst : MeshInstance3D
var _terrain_mat  : StandardMaterial3D
var _lattice_inst : MeshInstance3D
var _lattice_mat  : StandardMaterial3D
var _dot_inst     : MultiMeshInstance3D
var _dot_mm       : MultiMesh
var _water_inst   : MeshInstance3D

# ── HUD / param panel ─────────────────────────────────────────────────────────
var _lbl_info    : Label
var _lbl_dots    : Label
var _param_panel : Control
var _param_open  : bool = false
var _freq_slider : HSlider
var _amp_slider  : HSlider
var _seed_input  : LineEdit
var _rebuild_timer : float = 0.0    # debounce for slider changes that require rebake

# ── Animation ─────────────────────────────────────────────────────────────────
var _octave_t : float = 0.0
var _tween    : Tween


# ═════════════════════════════════════════════════════════════════════════════
func _ready() -> void:
	# _seed defaults to 1010 (Python terrain_viz default). Only inherit game seed
	# if the user explicitly set a non-default seed in the create-world screen.
	if GameSettingsAutoload.seed != GameSettings.DEFAULT_SEED:
		_seed = GameSettingsAutoload.seed
	_build_environment()
	# terrain / lattice / dot nodes must exist before _full_rebuild writes to them
	_create_terrain_node()
	_create_lattice_node()
	_create_dot_node()
	_create_water_node()
	_full_rebuild()
	_build_hud()
	_set_octave_t(0.0)
	# Souris CAPTURÉE par défaut — mêmes contrôles que dans le jeu.
	# Tab ouvre le panneau paramètres et libère la souris.


func _process(delta: float) -> void:
	# Debounce: rebuild shortly after a slider stops moving
	if _rebuild_timer > 0.0:
		_rebuild_timer -= delta
		if _rebuild_timer <= 0.0:
			_full_rebuild()
			_set_octave_t(0.0)


# ── Environment ───────────────────────────────────────────────────────────────
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode      = Environment.BG_COLOR
	env.background_color     = Color(0.44, 0.60, 0.82)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color  = Color(0.86, 0.89, 0.96)
	env.ambient_light_energy = 0.65
	env.fog_enabled          = false

	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50.0, 25.0, 0.0)
	sun.light_energy     = 1.4
	sun.shadow_enabled   = true
	add_child(sun)


# ── Full rebuild (gen + bake + meshes) ────────────────────────────────────────
func _full_rebuild() -> void:
	_gen = TerrainGenerator.new(_seed, MAX_OCTAVES)
	_h_baked.clear()
	_c_baked.clear()
	_bake_heights()
	_compute_dot_data()
	if _lattice_inst:
		_lattice_inst.mesh = _build_lattice_mesh()
	if _dot_mm:
		_init_dot_transforms()


# ── Height baking ─────────────────────────────────────────────────────────────
# Uses the real terrain pipeline (continentalness + peaks + shaped height FBM)
# so the final octave looks identical to the actual game.
# The origin (-V_SPACING, -V_SPACING) matches the vertex layout in _rebuild_terrain.
func _bake_heights() -> void:
	var ext   : int = MESH_SIZE + 2
	var total : int = ext * ext

	# oct = 0 : flat grey plane
	var fh := PackedFloat32Array(); fh.resize(total); fh.fill(0.0)
	var fc := PackedColorArray();   fc.resize(total); fc.fill(Color(0.52, 0.54, 0.57))
	_h_baked.append(fh)
	_c_baked.append(fc)

	for oct in range(1, MAX_OCTAVES + 1):
		var verts   := PackedVector3Array(); verts.resize(total)
		var climate := PackedColorArray();   climate.resize(total)
		# origin_x/z = -V_SPACING so vertex gx maps to world x = (gx-1)*V_SPACING
		_gen.get_vertex_data_batch(
			-V_SPACING, -V_SPACING, ext, ext, V_SPACING,
			verts, climate, oct, _freq,
		)

		var heights := PackedFloat32Array(); heights.resize(total)
		var colors  := PackedColorArray();   colors.resize(total)
		for i in range(total):
			heights[i] = verts[i].y
			colors[i]  = _biome_color(verts[i].y, climate[i])
		_h_baked.append(heights)
		_c_baked.append(colors)


# Approximate biome coloring matching the game shader palette.
# climate.r = temp_01, climate.g = moist_01, climate.b = cont_01 (all 0..1)
static func _biome_color(h: float, climate: Color) -> Color:
	var temp  := climate.r * 2.0 - 1.0   # back to -1..1
	var moist := climate.g * 2.0 - 1.0
	if h < TerrainConfig.SEA_LEVEL - 30.0:
		return Color(0.07, 0.15, 0.45)   # deep ocean
	if h < TerrainConfig.SEA_LEVEL:
		return Color(0.12, 0.28, 0.62)   # ocean
	if h < TerrainConfig.BEACH_HEIGHT:
		return Color(0.82, 0.76, 0.49)   # beach / sand
	if h >= TerrainConfig.HIGH_PEAKS_MIN:
		return Color(0.86, 0.90, 0.95)   # snow peaks
	if h >= TerrainConfig.SNOW_HEIGHT:
		return Color(0.55, 0.52, 0.47) if temp > TerrainConfig.TUNDRA_TEMP \
			else Color(0.84, 0.87, 0.93)   # bare rock vs snow mountains
	if h >= TerrainConfig.HIGHLANDS_MIN:
		return Color(0.68, 0.70, 0.65) if temp < TerrainConfig.TUNDRA_TEMP \
			else Color(0.30, 0.46, 0.24)   # tundra vs highland forest
	if temp > TerrainConfig.HOT_TEMP:
		return Color(0.76, 0.65, 0.30) if moist < TerrainConfig.JUNGLE_MOIST \
			else Color(0.12, 0.48, 0.12)   # desert vs jungle
	if moist > TerrainConfig.FOREST_MOIST:
		return Color(0.19, 0.42, 0.16)   # forest
	return Color(0.38, 0.62, 0.24)       # plains


# ── Terrain mesh ──────────────────────────────────────────────────────────────
func _create_terrain_node() -> void:
	_terrain_mat = StandardMaterial3D.new()
	_terrain_mat.vertex_color_use_as_albedo = true
	_terrain_mat.roughness                  = 0.9
	_terrain_inst      = MeshInstance3D.new()
	_terrain_inst.mesh = ArrayMesh.new()
	add_child(_terrain_inst)


func _rebuild_terrain(t: float) -> void:
	var t_lo := clampi(floori(t), 0, MAX_OCTAVES)
	var t_hi := clampi(ceili(t),  0, MAX_OCTAVES)
	var frac := t - float(t_lo)
	var ext  := MESH_SIZE + 2
	var ox   := V_SPACING

	var verts  := PackedVector3Array(); verts.resize(ext * ext)
	var colors := PackedColorArray();   colors.resize(ext * ext)
	for i in range(ext * ext):
		verts[i]  = Vector3(
			(i % ext) * V_SPACING - ox,
			lerpf(_h_baked[t_lo][i], _h_baked[t_hi][i], frac) * _amp_scale,
			(i / ext) * V_SPACING - ox,
		)
		colors[i] = _c_baked[t_lo][i].lerp(_c_baked[t_hi][i], frac)

	var normals := _calc_normals(verts, ext)
	var indices := ChunkMeshBuilder.get_or_build_index_buffer(MESH_SIZE, 1)
	var arr     := Array(); arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	arr[Mesh.ARRAY_NORMAL] = normals
	arr[Mesh.ARRAY_COLOR]  = colors
	arr[Mesh.ARRAY_INDEX]  = indices

	var mesh := _terrain_inst.mesh as ArrayMesh
	mesh.clear_surfaces()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	mesh.surface_set_material(0, _terrain_mat)


func _calc_normals(verts: PackedVector3Array, ext: int) -> PackedVector3Array:
	var nrm := PackedVector3Array(); nrm.resize(verts.size())
	for z in range(ext):
		for x in range(ext):
			var i  := z * ext + x
			var hc := verts[i].y
			var hl := verts[i - 1].y   if x > 0        else hc
			var hr := verts[i + 1].y   if x < ext - 1  else hc
			var hu := verts[i - ext].y if z > 0        else hc
			var hd := verts[i + ext].y if z < ext - 1  else hc
			nrm[i] = Vector3((hl - hr) / (2.0 * V_SPACING), 1.0, (hu - hd) / (2.0 * V_SPACING)).normalized()
	return nrm


# ── Lattice visualization ─────────────────────────────────────────────────────
func _create_lattice_node() -> void:
	_lattice_mat = StandardMaterial3D.new()
	_lattice_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_lattice_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_lattice_mat.albedo_color = Color(0.07, 0.09, 0.20, 1.0)
	_lattice_inst                   = MeshInstance3D.new()
	_lattice_inst.material_override = _lattice_mat
	add_child(_lattice_inst)


func _build_lattice_mesh() -> ArrayMesh:
	var pn   : PerlinNoise      = _gen.height_noise.generators[0]
	var perm : PackedInt32Array = pn._perm_table
	var y    : float            = GRID_Y
	# Arrow length = 15% of Perlin cell size; auto-scales with _freq
	var arrow_len : float = 0.15 / _freq
	var verts := PackedVector3Array()
	var n0 := floori(0.0        * _freq + pn.x_offset)
	var n1 := ceili(MESH_WORLD * _freq + pn.x_offset)
	var m0 := floori(0.0        * _freq + pn.z_offset)
	var m1 := ceili(MESH_WORLD * _freq + pn.z_offset)

	for m in range(m0, m1 + 1):
		var wz := clampf((float(m) - pn.z_offset) / _freq, 0.0, MESH_WORLD)
		verts.append(Vector3(0.0, y, wz)); verts.append(Vector3(MESH_WORLD, y, wz))
	for n in range(n0, n1 + 1):
		var wx := clampf((float(n) - pn.x_offset) / _freq, 0.0, MESH_WORLD)
		verts.append(Vector3(wx, y, 0.0)); verts.append(Vector3(wx, y, MESH_WORLD))

	for m in range(m0, m1 + 1):
		for n in range(n0, n1 + 1):
			var wx := (float(n) - pn.x_offset) / _freq
			var wz := (float(m) - pn.z_offset) / _freq
			if wx < 0.0 or wx > MESH_WORLD or wz < 0.0 or wz > MESH_WORLD: continue
			var aa    := perm[perm[n & 255]] + (m & 255)
			var g_idx := perm[aa] & 15
			var gx := PerlinNoise.GRAD_X[g_idx]; var gz := PerlinNoise.GRAD_Z[g_idx]
			if gx == 0.0 and gz == 0.0: continue
			var dir  := Vector3(gx, 0.0, gz)
			var perp := Vector3(-dir.z, 0.0, dir.x)
			var tip  := Vector3(wx, y, wz) + dir * arrow_len
			var from := Vector3(wx, y, wz)
			verts.append(from); verts.append(tip)
			verts.append(tip);  verts.append(tip - dir * arrow_len * 0.30 + perp * arrow_len * 0.18)
			verts.append(tip);  verts.append(tip - dir * arrow_len * 0.30 - perp * arrow_len * 0.18)

	var arr := Array(); arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = verts
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, arr)
	return mesh


# ── Centre-of-cell dots (rise to show noise elevation) ────────────────────────
func _create_dot_node() -> void:
	var sphere := SphereMesh.new()
	# Radius scales with V_SPACING so dots stay visible at 2000 wu scale
	sphere.radius = V_SPACING * 0.35
	sphere.height = V_SPACING * 0.70
	sphere.radial_segments = 8
	sphere.rings = 4
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.08, 0.08, 0.16)
	mat.roughness    = 0.6
	sphere.surface_set_material(0, mat)

	_dot_mm = MultiMesh.new()
	_dot_mm.transform_format = MultiMesh.TRANSFORM_3D
	_dot_mm.mesh             = sphere

	_dot_inst           = MultiMeshInstance3D.new()
	_dot_inst.multimesh = _dot_mm
	add_child(_dot_inst)


func _compute_dot_data() -> void:
	_dot_data.clear()
	var pn  := _gen.height_noise.generators[0]
	var ext : int = MESH_SIZE + 2
	var n0  := floori(0.0        * _freq + pn.x_offset)
	var n1  := ceili(MESH_WORLD * _freq + pn.x_offset)
	var m0  := floori(0.0        * _freq + pn.z_offset)
	var m1  := ceili(MESH_WORLD * _freq + pn.z_offset)
	for m in range(m0, m1):
		for n in range(n0, n1):
			var wx := ((float(n) + 0.5) - pn.x_offset) / _freq
			var wz := ((float(m) + 0.5) - pn.z_offset) / _freq
			if wx < 0.0 or wx > MESH_WORLD or wz < 0.0 or wz > MESH_WORLD: continue
			# Sample oct-1 height from baked data at the nearest grid vertex.
			# Grid: vertex gx is at world x = (gx - 1)*V_SPACING → gx = wx/V_SPACING + 1
			var gx := clampi(roundi(wx / V_SPACING) + 1, 0, ext - 1)
			var gz := clampi(roundi(wz / V_SPACING) + 1, 0, ext - 1)
			var h1 := _h_baked[1][gz * ext + gx]
			_dot_data.append({"wx": wx, "wz": wz, "h1": h1})


func _init_dot_transforms() -> void:
	_dot_mm.instance_count = _dot_data.size()
	for i in range(_dot_data.size()):
		var d : Dictionary = _dot_data[i]
		_dot_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(d.wx, GRID_Y, d.wz)))


func _update_dots(t: float) -> void:
	# Dots visible during t = 0..1.5 (phase: flat grid + first octave rise)
	_dot_inst.visible = t < 1.5
	if not _dot_inst.visible or _dot_data.is_empty(): return
	var rise_t := clampf(t, 0.0, 1.0)   # 0 → flat level, 1 → oct-1 height
	for i in range(_dot_data.size()):
		var d : Dictionary = _dot_data[i]
		var y := lerpf(GRID_Y, d.h1 * _amp_scale, rise_t)
		_dot_mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(d.wx, y, d.wz)))


# ── Water plane ───────────────────────────────────────────────────────────────
func _create_water_node() -> void:
	var plane := PlaneMesh.new()
	plane.size           = Vector2(MESH_WORLD + 60.0, MESH_WORLD + 60.0)
	plane.subdivide_width = 0
	plane.subdivide_depth = 0

	var mat := StandardMaterial3D.new()
	mat.albedo_color   = Color(0.12, 0.38, 0.72, 0.68)
	mat.transparency   = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.roughness      = 0.05
	mat.metallic       = 0.15
	mat.shading_mode   = BaseMaterial3D.SHADING_MODE_PER_PIXEL

	_water_inst                   = MeshInstance3D.new()
	_water_inst.mesh              = plane
	_water_inst.material_override = mat
	_water_inst.position          = Vector3(MESH_WORLD * 0.5, 0.0, MESH_WORLD * 0.5)
	add_child(_water_inst)


# ── HUD ───────────────────────────────────────────────────────────────────────
func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	# ── Bottom strip ─────────────────────────────────────────────────────────
	var bg := ColorRect.new()
	bg.color = Color(0.06, 0.08, 0.16, 0.78)
	bg.anchor_left = 0.0; bg.anchor_right = 1.0
	bg.anchor_top  = 1.0; bg.anchor_bottom = 1.0
	bg.offset_top  = -72.0; bg.offset_bottom = 0.0
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)

	_lbl_info = Label.new()
	_lbl_info.anchor_left = 0.0; _lbl_info.anchor_right = 1.0
	_lbl_info.anchor_top  = 1.0; _lbl_info.anchor_bottom = 1.0
	_lbl_info.offset_top  = -70.0; _lbl_info.offset_bottom = -44.0
	_lbl_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_info.add_theme_font_size_override("font_size", 14)
	_lbl_info.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_lbl_info)

	_lbl_dots = Label.new()
	_lbl_dots.anchor_left = 0.0; _lbl_dots.anchor_right = 1.0
	_lbl_dots.anchor_top  = 1.0; _lbl_dots.anchor_bottom = 1.0
	_lbl_dots.offset_top  = -42.0; _lbl_dots.offset_bottom = -18.0
	_lbl_dots.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_lbl_dots.add_theme_font_size_override("font_size", 20)
	_lbl_dots.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_lbl_dots)

	var hint := Label.new()
	hint.anchor_left = 0.0; hint.anchor_right = 1.0
	hint.anchor_top  = 1.0; hint.anchor_bottom = 1.0
	hint.offset_top  = -18.0; hint.offset_bottom = 0.0
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.add_theme_font_size_override("font_size", 10)
	hint.text = "← →  octave   |   Entrée  animer   |   Tab  paramètres   |   ESC  retour"
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint)

	# ── Side param panel (hidden by default) ─────────────────────────────────
	_param_panel = _build_param_panel()
	_param_panel.visible = false
	root.add_child(_param_panel)


func _build_param_panel() -> Control:
	var panel := PanelContainer.new()
	panel.anchor_left   = 0.0; panel.anchor_right  = 0.0
	panel.anchor_top    = 0.0; panel.anchor_bottom = 0.0
	panel.offset_right  = 260.0; panel.offset_bottom = 330.0
	panel.offset_top    = 10.0; panel.offset_left = 10.0

	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vbox.add_theme_constant_override("separation", 6)
	panel.add_child(vbox)

	var title := Label.new()
	title.text = "Paramètres"
	title.add_theme_font_size_override("font_size", 13)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	vbox.add_child(title)

	# ── Frequency ────────────────────────────────────────────────────────────
	# Default 0.0005 = TerrainConfig.HEIGHT_FREQ = matches Python terrain_viz
	vbox.add_child(_make_label("Fréquence hauteur  (0.0005 = jeu réel)"))
	_freq_slider = HSlider.new()
	_freq_slider.min_value = 0.0001; _freq_slider.max_value = 0.002
	_freq_slider.step = 0.0001; _freq_slider.value = _freq
	_freq_slider.value_changed.connect(_on_freq_changed)
	vbox.add_child(_freq_slider)

	# ── Amplitude scale ───────────────────────────────────────────────────────
	vbox.add_child(_make_label("Amplitude (×1.0 = jeu réel)"))
	_amp_slider = HSlider.new()
	_amp_slider.min_value = 0.1; _amp_slider.max_value = 3.0
	_amp_slider.step = 0.05; _amp_slider.value = _amp_scale
	_amp_slider.value_changed.connect(_on_amp_changed)
	vbox.add_child(_amp_slider)

	# ── Seed ──────────────────────────────────────────────────────────────────
	vbox.add_child(_make_label("Seed  (1010 = défaut Python)"))
	var seed_row := HBoxContainer.new()
	vbox.add_child(seed_row)
	_seed_input = LineEdit.new()
	_seed_input.text = str(_seed)
	_seed_input.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_seed_input)
	var apply_btn := Button.new()
	apply_btn.text = "OK"
	apply_btn.pressed.connect(_on_seed_apply)
	seed_row.add_child(apply_btn)

	# ── Close ─────────────────────────────────────────────────────────────────
	var close_btn := Button.new()
	close_btn.text = "Fermer  (Tab)"
	close_btn.pressed.connect(_toggle_params)
	vbox.add_child(close_btn)

	return panel


static func _make_label(txt: String) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", 11)
	return l


# ── Input ─────────────────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if not (event is InputEventKey): return
	var ke := event as InputEventKey
	if not ke.pressed: return

	# When param panel is open, only process Tab (close) and ESC (back).
	# All other keys are left for the UI (LineEdit, sliders, button).
	if _param_open:
		if ke.keycode == KEY_TAB:
			get_viewport().set_input_as_handled()
			_toggle_params()
		elif ke.keycode == KEY_ESCAPE:
			get_viewport().set_input_as_handled()
			_go_back()
		return

	if event.is_action_pressed("toggle_menu"):
		get_viewport().set_input_as_handled()
		_go_back()
		return

	if event.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_toggle_play()
		return

	if event.is_action_pressed("ui_right") or event.is_action_pressed("ui_page_down"):
		get_viewport().set_input_as_handled()
		_animate_to(minf(_octave_t + 1.0, float(MAX_OCTAVES)))
		return

	if event.is_action_pressed("ui_left") or event.is_action_pressed("ui_page_up"):
		get_viewport().set_input_as_handled()
		_animate_to(maxf(_octave_t - 1.0, 0.0))
		return

	if ke.keycode == KEY_TAB:
		get_viewport().set_input_as_handled()
		_toggle_params()


func _toggle_params() -> void:
	_param_open = not _param_open
	_param_panel.visible = _param_open
	Input.set_mouse_mode(
		Input.MOUSE_MODE_VISIBLE if _param_open else Input.MOUSE_MODE_CAPTURED
	)


# ── Parameter callbacks ───────────────────────────────────────────────────────
func _on_freq_changed(v: float) -> void:
	_freq = v
	_rebuild_timer = 0.35   # debounce (requires full rebake)

# Amplitude is applied at render time — no rebake needed, just redraw current t.
func _on_amp_changed(v: float) -> void:
	_amp_scale = v
	_set_octave_t(_octave_t)

func _on_seed_apply() -> void:
	var txt := _seed_input.text.strip_edges()
	_seed = int(txt) if txt.is_valid_int() else 1010
	_full_rebuild()
	_set_octave_t(0.0)


# ── Playback ──────────────────────────────────────────────────────────────────
func _toggle_play() -> void:
	if _tween and _tween.is_running():
		_tween.kill(); _tween = null; return

	if _octave_t >= float(MAX_OCTAVES) - 0.01:
		_set_octave_t(0.0)

	_tween = create_tween()
	_tween.tween_method(
		_set_octave_t, _octave_t, float(MAX_OCTAVES),
		(float(MAX_OCTAVES) - _octave_t) * ANIM_DUR,
	)
	_tween.finished.connect(func() -> void: _tween = null)


func _animate_to(target: float) -> void:
	if _tween: _tween.kill(); _tween = null
	_tween = create_tween()
	_tween.tween_method(_set_octave_t, _octave_t, target, 0.4)
	_tween.finished.connect(func() -> void: _tween = null)


# ── State update ──────────────────────────────────────────────────────────────
func _set_octave_t(t: float) -> void:
	_octave_t = t
	_rebuild_terrain(t)
	_update_dots(t)

	var alpha := clampf(1.0 - t * 2.0, 0.0, 1.0)
	_lattice_mat.albedo_color.a = alpha
	_lattice_inst.visible       = alpha > 0.001

	_lbl_info.text = _info_for(t)
	_lbl_dots.text = _dots_for(t)


func _go_back() -> void:
	get_tree().paused = false
	Input.set_mouse_mode(Input.MOUSE_MODE_CAPTURED)
	get_tree().change_scene_to_file("res://scenes/main/terrain_world.tscn")


# ── Static helpers ────────────────────────────────────────────────────────────
static func _info_for(t: float) -> String:
	if t < 0.05: return "Lattice Perlin – vecteurs gradients aux coins · points = centre des cellules"
	if t < 1.05: return "Octave 1 – les points montent à leur hauteur de bruit  (fréquence f₀)"
	if t < 2.05: return "Octave 2 – détails moyens  (f₀×2,  amplitude ×½)"
	if t < 3.05: return "Octave 3 – détails fins    (f₀×4,  amplitude ×¼)"
	if t < 4.05: return "Octave 4 – micro-relief    (f₀×8,  amplitude ×⅛)"
	if t < 5.05: return "Octave 5 – rugosité         (f₀×16)"
	return              "Terrain final – FBM complet · mer visible sous le niveau 0"


static func _dots_for(t: float) -> String:
	var filled := clampi(roundi(t), 0, MAX_OCTAVES)
	var s := ""
	for i in range(MAX_OCTAVES):
		s += "◉ " if i < filled else "○ "
	return s.strip_edges()
