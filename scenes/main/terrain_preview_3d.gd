extends SubViewport

@onready var cam3d: Camera3D = get_node("Root3D/Camera3D")
@onready var chunk_mesh: MeshInstance3D = get_node("Root3D/ChunkMesh")
@onready var preview_rect: TextureRect = $"../MarginContainer/VBoxContainer/Scroll/HBoxContainer/Preview3D"

@export var mesh_size_3d: int = 40
@export var max_octaves_3d: int = 6
@export var auto_frame_mesh: bool = true
@export var auto_frame_margin: float = 1.15
@export var auto_frame_max_distance: float = 1200.0
@export var intermediate_height_freq: float = 0.005

@export var orbit_distance: float = 160.0
@export var orbit_distance_min: float = 20.0
@export var orbit_distance_max: float = 600.0
@export var orbit_sensitivity: float = 0.01
@export var zoom_speed: float = 18.0
@export var pan_speed: float = 0.12
@export var orbit_button: MouseButton = MOUSE_BUTTON_LEFT

var chunk_size: int
var vertex_spacing: float
var chunk_pos: Vector2i

var _orbit_yaw: float = 0.78
var _orbit_pitch: float = 1.0
var _orbit_target: Vector3 = Vector3.ZERO
var _dragging_orbit: bool = false
var _dragging_pan: bool = false


func _ready() -> void:
	_setup_viewport_3d()


func configure(p_chunk_size: int, p_vertex_spacing: float, p_chunk_pos: Vector2i) -> void:
	chunk_size = p_chunk_size
	vertex_spacing = p_vertex_spacing
	chunk_pos = p_chunk_pos


func render_preview(gen: TerrainGenerator) -> void:
	var builder := ChunkMeshBuilder.new(
		chunk_size,
		vertex_spacing,
		gen,
		mesh_size_3d,
		max_octaves_3d,
		intermediate_height_freq
	)

	var mesh: ArrayMesh = builder.build_chunk_mesh(Vector2(chunk_pos.x, chunk_pos.y))
	chunk_mesh.mesh = mesh
	chunk_mesh.material_override = _create_chunk_material()

	if auto_frame_mesh:
		_frame_camera_on_mesh()
	else:
		var size_world := float((chunk_size - 1) * vertex_spacing)
		_orbit_target = Vector3(size_world * 0.5, 0.0, size_world * 0.5)
		_position_camera()


func zoom_in() -> void:
	orbit_distance -= zoom_speed
	_position_camera()

func zoom_out() -> void:
	orbit_distance += zoom_speed
	_position_camera()

func set_orbit_dragging(active: bool) -> void:
	_dragging_orbit = active

func set_pan_dragging(active: bool) -> void:
	_dragging_pan = active

func orbit_by(delta: Vector2) -> void:
	_orbit_yaw -= delta.x * orbit_sensitivity
	_orbit_pitch -= delta.y * orbit_sensitivity
	_position_camera()

func pan_by(delta: Vector2) -> void:
	var right := cam3d.global_transform.basis.x.normalized()
	var up := cam3d.global_transform.basis.y.normalized()
	_orbit_target += (-right * delta.x + up * delta.y) * pan_speed
	_position_camera()

func _setup_viewport_3d() -> void:
	disable_3d = false
	own_world_3d = true
	cam3d.current = true
	world_3d = _create_preview_world()
	preview_rect.texture = get_texture()


func _create_preview_world() -> World3D:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.75, 0.75, 0.75)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 1.0

	var world := World3D.new()
	world.environment = env
	return world


func _is_mouse_over_3d_preview() -> bool:
	var mouse_pos := preview_rect.get_viewport().get_mouse_position()
	return preview_rect.get_global_rect().has_point(mouse_pos)

func _stop_camera_drag() -> void:
	_dragging_orbit = false
	_dragging_pan = false


func _handle_zoom_input(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.pressed:
			if mb.button_index == MOUSE_BUTTON_WHEEL_UP:
				orbit_distance -= zoom_speed
				_position_camera()
				return true
			elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN:
				orbit_distance += zoom_speed
				_position_camera()
				return true

	return false


func _handle_mouse_button_drag(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton

		if mb.button_index == orbit_button:
			_dragging_orbit = mb.pressed
			return true
		elif mb.button_index == MOUSE_BUTTON_MIDDLE:
			_dragging_pan = mb.pressed
			return true

	return false


func _handle_mouse_motion(event: InputEvent) -> void:
	if event is not InputEventMouseMotion:
		return

	var motion := event as InputEventMouseMotion
	var delta := motion.relative

	if _dragging_orbit:
		_orbit_yaw -= delta.x * orbit_sensitivity
		_orbit_pitch -= delta.y * orbit_sensitivity
		_position_camera()
		return

	if _dragging_pan:
		var right := cam3d.global_transform.basis.x.normalized()
		var up := cam3d.global_transform.basis.y.normalized()
		_orbit_target += (-right * delta.x + up * delta.y) * pan_speed
		_position_camera()


func _position_camera() -> void:
	var eps := 0.0001
	var max_pitch := PI * 0.5 - eps

	_orbit_pitch = clampf(_orbit_pitch, -max_pitch, max_pitch)
	orbit_distance = clampf(orbit_distance, orbit_distance_min, orbit_distance_max)

	var dir := Vector3(
		cos(_orbit_pitch) * cos(_orbit_yaw),
		sin(_orbit_pitch),
		cos(_orbit_pitch) * sin(_orbit_yaw)
	)

	cam3d.global_position = _orbit_target + dir * orbit_distance
	cam3d.look_at(_orbit_target, Vector3.UP)


func _create_chunk_material() -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 1.0
	return mat


func _frame_camera_on_mesh() -> void:
	if chunk_mesh == null or chunk_mesh.mesh == null:
		return

	var mesh := chunk_mesh.mesh
	var array_mesh := mesh as ArrayMesh

	if array_mesh != null:
		_apply_frame_from_aabb(array_mesh.get_aabb())
	else:
		_apply_frame_from_aabb(mesh.get_aabb())


func _apply_frame_from_aabb(aabb_local: AABB) -> void:
	var center_local := aabb_local.position + aabb_local.size * 0.5
	var center_global := chunk_mesh.global_transform * center_local
	_orbit_target = center_global

	var radius := aabb_local.size.length() * 0.5
	radius *= auto_frame_margin
	radius = maxf(radius, 0.01)

	var fov_rad := deg_to_rad(cam3d.fov)
	var distance := radius / tan(fov_rad * 0.5)
	distance = clampf(distance, orbit_distance_min, min(orbit_distance_max, auto_frame_max_distance))
	orbit_distance = distance

	_position_camera()
