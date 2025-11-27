class_name MainCamera
extends Camera3D

# ============================================================================
# EXPORTS
# ============================================================================

@export var lerp_speed:  float = 3.0
@export var target_path: NodePath
@export var offset:      Vector3 = Vector3.ZERO

var target = null

# ============================================================================
# INITIALIZATION
# ============================================================================

func _ready() -> void:
	if target_path:
		target = get_node(target_path)

func _physics_process(delta):
	if !target:
		return
	
	var corrected_offset = Vector3(offset.x, offset.y, -offset.z)
	var target_pos = target.global_transform.translated_local(corrected_offset).origin
	global_transform.origin = global_transform.origin.lerp(target_pos, lerp_speed * delta)
	
	var new_basis = global_transform.looking_at(target.global_transform.origin, target.transform.basis.y)
	global_transform = global_transform.interpolate_with(new_basis, lerp_speed * delta)
