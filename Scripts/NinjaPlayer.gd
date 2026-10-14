extends CharacterBody3D
# Ninja player - same controls as the Platformer Starter (WASD + mouse camera + Space double jump) + slash

signal slashed(center: Vector3, radius: float)

@export var move_speed := 7.0
@export var jump_force := 7.5
@export var follow_lerp_factor := 4.0
@export var slash_radius := 3.6

var gravity: float = 19.6
var can_double := false
var knock := Vector3.ZERO
var slash_cd := 0.0
var invincible := 0.0
var t := 0.0
var gimbal: Node3D
var model: Node3D
var body: Node3D
var arm: Node3D
var leg_l: Node3D
var leg_r: Node3D

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func _part(parent: Node, size: Vector3, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = size
	mi.mesh = b
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _ready() -> void:
	add_to_group("Player")
	# collision
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.6
	cs.shape = cap
	cs.position = Vector3(0, 0.8, 0)
	add_child(cs)
	# ninja model (front faces +Z)
	model = Node3D.new()
	add_child(model)
	body = Node3D.new()
	model.add_child(body)
	var black := Color(0.08, 0.08, 0.1)
	var red := Color(0.85, 0.1, 0.1)
	_part(body, Vector3(0.7, 0.8, 0.4), black, Vector3(0, 1.0, 0))
	_part(body, Vector3(0.75, 0.15, 0.45), red, Vector3(0, 0.65, 0))
	var head := MeshInstance3D.new()
	head.mesh = SphereMesh.new()
	head.material_override = _mat(black)
	head.scale = Vector3.ONE * 0.6
	head.position = Vector3(0, 1.65, 0)
	body.add_child(head)
	_part(body, Vector3(0.5, 0.12, 0.05), Color(1, 0.85, 0.7), Vector3(0, 1.68, 0.28))
	_part(body, Vector3(0.62, 0.12, 0.62), red, Vector3(0, 1.85, 0))
	_part(body, Vector3(0.15, 0.1, 0.7), red, Vector3(0, 1.85, -0.55))
	var sw := _part(body, Vector3(0.08, 1.0, 0.08), Color(0.6, 0.6, 0.65), Vector3(0.1, 1.1, -0.3))
	sw.rotation_degrees = Vector3(0, 0, 40)
	leg_l = Node3D.new(); leg_l.position = Vector3(-0.2, 0.65, 0); body.add_child(leg_l)
	leg_r = Node3D.new(); leg_r.position = Vector3(0.2, 0.65, 0); body.add_child(leg_r)
	_part(leg_l, Vector3(0.28, 0.65, 0.3), black, Vector3(0, -0.32, 0))
	_part(leg_r, Vector3(0.28, 0.65, 0.3), black, Vector3(0, -0.32, 0))
	var arm_l := Node3D.new(); arm_l.position = Vector3(-0.5, 1.3, 0); body.add_child(arm_l)
	_part(arm_l, Vector3(0.22, 0.65, 0.25), black, Vector3(0, -0.28, 0))
	arm = Node3D.new(); arm.position = Vector3(0.5, 1.3, 0); body.add_child(arm)
	_part(arm, Vector3(0.22, 0.65, 0.25), black, Vector3(0, -0.28, 0))
	_part(arm, Vector3(0.07, 0.07, 1.3), Color(0.85, 0.9, 1.0), Vector3(0, -0.55, 0.8))
	_part(arm, Vector3(0.14, 0.14, 0.25), Color(0.4, 0.25, 0.1), Vector3(0, -0.55, 0.05))
	# camera gimbal using the original camera script
	gimbal = Node3D.new()
	gimbal.set_script(load("res://Scripts/CameraMovement.gd"))
	var cam := Camera3D.new()
	cam.name = "Camera3D"
	cam.position = Vector3(0, 2, 5)
	cam.rotation_degrees = Vector3(-15, 0, 0)
	cam.current = true
	gimbal.add_child(cam)
	gimbal.rotation_degrees = Vector3(-20, 0, 0)
	add_child(gimbal)
	gimbal.global_position = global_position + Vector3(0, 1, 0)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and not e.echo:
		if e.physical_keycode == KEY_J or e.physical_keycode == KEY_K or e.physical_keycode == KEY_E:
			slash()
	elif e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			slash()

func slash() -> void:
	if slash_cd > 0.0:
		return
	slash_cd = 0.3
	var tw := create_tween()
	arm.rotation.x = -2.2
	tw.tween_property(arm, "rotation:x", 1.2, 0.12)
	tw.tween_property(arm, "rotation:x", 0.0, 0.15)
	# spin-slash ring
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.9
	tm.outer_radius = 2.4
	ring.mesh = tm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(0.8, 0.95, 1.0, 0.85)
	ring.material_override = m
	ring.scale = Vector3(1, 0.1, 1)
	get_parent().add_child(ring)
	ring.global_position = global_position + Vector3(0, 1.1, 0)
	var tw2 := create_tween().set_parallel(true)
	tw2.tween_property(ring, "rotation:y", TAU, 0.2)
	tw2.tween_property(m, "albedo_color:a", 0.0, 0.25)
	tw2.chain().tween_callback(ring.queue_free)
	emit_signal("slashed", global_position + Vector3(0, 1.0, 0), slash_radius)

func _physics_process(delta: float) -> void:
	t += delta
	slash_cd = maxf(0.0, slash_cd - delta)
	invincible = maxf(0.0, invincible - delta)
	var dir := Vector3(Input.get_axis("move_left", "move_right"), 0, Input.get_axis("move_forward", "move_back"))
	dir = dir.rotated(Vector3.UP, gimbal.rotation.y).normalized()
	velocity.x = dir.x * move_speed + knock.x
	velocity.z = dir.z * move_speed + knock.z
	knock = knock.move_toward(Vector3.ZERO, 25.0 * delta)
	if is_on_floor():
		can_double = true
	if Input.is_action_just_pressed("jump"):
		if is_on_floor():
			velocity.y = jump_force
			AudioManager.jump_sfx.pitch_scale = 1.12
			AudioManager.jump_sfx.play()
		elif can_double:
			can_double = false
			velocity.y = jump_force
			AudioManager.jump_sfx.pitch_scale = 0.8
			AudioManager.jump_sfx.play()
			body.rotation.x = 0.0
			var tw := create_tween()
			tw.tween_property(body, "rotation:x", TAU, 0.4)
			tw.tween_callback(func(): body.rotation.x = 0.0)
	velocity.y -= gravity * delta
	move_and_slide()
	var moving := absf(velocity.x - knock.x) > 0.1 or absf(velocity.z - knock.z) > 0.1
	gimbal.position = gimbal.position.lerp(position + Vector3(0, 1, 0), delta * follow_lerp_factor)
	if dir.length() > 0.0:
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), delta * 12.0)
	var sw := sin(t * 16.0) * 0.9 if (moving and is_on_floor()) else 0.0
	leg_l.rotation.x = sw
	leg_r.rotation.x = -sw
	model.visible = invincible <= 0.0 or int(t * 15.0) % 2 == 0
