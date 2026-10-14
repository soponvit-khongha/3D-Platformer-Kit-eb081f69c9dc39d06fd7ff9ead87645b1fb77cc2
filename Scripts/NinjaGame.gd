extends Node3D
# Ninja level: jump across floating platforms, dodge spikes/blades, slash flying objects for points.

const N := 10  # middle platforms
const XOFF := [0, 2, -2, 2, -2, 2, -2, 2, -2, 0, 0, 0]

var player
var platforms: Array = []   # {pos(top center), half}
var blades: Array = []      # {node, base, amp, phase, half}
var spikes: Array = []      # {center, half}
var flyers: Array = []      # {node, vel, kind, life}
var score := 0
var lives := 3
var state := "play"
var t := 0.0
var spawn_t := 2.0
var checkpoint := Vector3(0, 1, 0)
var goal := Vector3.ZERO
var hud: Label
var msg: Label

func _mat(c: Color, unshaded := false) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _mesh(parent: Node, mesh: Mesh, c: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(c)
	mi.position = pos
	parent.add_child(mi)
	return mi

func _box(s: Vector3) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = s
	return b

func _ready() -> void:
	randomize()
	_build_env()
	_build_level()
	player = load("res://Scripts/NinjaPlayer.gd").new()
	player.position = Vector3(0, 1, 0)
	add_child(player)
	player.slashed.connect(_on_slash)
	_build_ui()

func _build_env() -> void:
	var we := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.25, 0.2, 0.4)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.7, 0.68, 0.85)
	env.ambient_light_energy = 1.0
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)
	var moon := _mesh(self, SphereMesh.new(), Color(1, 0.95, 0.8), Vector3(30, 60, -170))
	moon.material_override = _mat(Color(1, 0.95, 0.8), true)
	moon.scale = Vector3.ONE * 25

func _add_platform(center_xz: Vector2, top_y: float, size: Vector3, c: Color) -> void:
	var sb := StaticBody3D.new()
	sb.position = Vector3(center_xz.x, top_y - size.y / 2.0, center_xz.y)
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	_mesh(sb, _box(size), c, Vector3.ZERO)
	add_child(sb)
	platforms.append({"pos": Vector3(center_xz.x, top_y, center_xz.y), "half": Vector2(size.x / 2.0, size.z / 2.0)})

func _build_level() -> void:
	var red := Color(0.85, 0.25, 0.25)
	var blue := Color(0.25, 0.45, 0.9)
	_add_platform(Vector2(0, 0), 0.0, Vector3(10, 1, 10), blue)
	for i in range(1, N + 1):
		var x: float = XOFF[i]
		var z := -i * 11.5
		var y := i * 0.5
		_add_platform(Vector2(x, z), y, Vector3(8, 1, 8), red if i % 2 == 1 else blue)
		if i % 3 == 0:
			_add_spikes(Vector3(x + (-1.5 if i % 2 == 0 else 1.5), y, z))
		elif i % 3 == 1 and i > 1:
			_add_blade(Vector3(x, y, z))
	# goal platform
	var gi := N + 1
	var gp := Vector3(0, gi * 0.5, -gi * 11.5)
	_add_platform(Vector2(gp.x, gp.z), gp.y, Vector3(10, 1, 10), Color(0.95, 0.75, 0.2))
	goal = gp
	var pole := CylinderMesh.new()
	pole.top_radius = 0.1; pole.bottom_radius = 0.1; pole.height = 5.0
	_mesh(self, pole, Color(0.9, 0.9, 0.9), gp + Vector3(0, 2.5, -2))
	_mesh(self, _box(Vector3(0.1, 1.2, 2.0)), Color(0.85, 0.1, 0.1), gp + Vector3(0, 4.2, -3.0))

func _add_spikes(base: Vector3) -> void:
	var n := Node3D.new()
	n.position = base
	add_child(n)
	_mesh(n, _box(Vector3(3, 0.3, 1.2)), Color(0.2, 0.2, 0.25), Vector3(0, 0.15, 0))
	for k in 4:
		var c := CylinderMesh.new()
		c.top_radius = 0.0; c.bottom_radius = 0.3; c.height = 0.7
		_mesh(n, c, Color(0.85, 0.85, 0.9), Vector3(-1.1 + k * 0.73, 0.55, 0))
	spikes.append({"center": base + Vector3(0, 0.3, 0), "half": Vector3(1.5, 0.45, 0.6)})

func _add_blade(base: Vector3) -> void:
	var n := Node3D.new()
	n.position = base + Vector3(0, 0.5, 0)
	add_child(n)
	_mesh(n, _box(Vector3(1.6, 1.0, 0.4)), Color(0.8, 0.1, 0.15), Vector3.ZERO)
	_mesh(n, _box(Vector3(1.0, 0.6, 0.5)), Color(0.9, 0.9, 0.95), Vector3.ZERO)
	blades.append({"node": n, "base": n.position, "amp": 2.8, "phase": randf() * 6.0, "half": Vector3(0.8, 0.5, 0.25)})

func _build_ui() -> void:
	var cl := CanvasLayer.new()
	add_child(cl)
	hud = Label.new()
	hud.position = Vector2(20, 14)
	hud.add_theme_font_size_override("font_size", 28)
	cl.add_child(hud)
	msg = Label.new()
	msg.set_anchors_preset(Control.PRESET_FULL_RECT)
	msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	msg.add_theme_font_size_override("font_size", 40)
	cl.add_child(msg)

func _hit_box(center: Vector3, half: Vector3) -> bool:
	var p: Vector3 = player.global_position
	return absf(p.x - center.x) < half.x + 0.35 and absf(p.z - center.z) < half.z + 0.35 and p.y < center.y + half.y and p.y + 1.6 > center.y - half.y

func _hurt(from: Vector3) -> void:
	if player.invincible > 0.0 or state != "play":
		return
	lives -= 1
	player.invincible = 1.5
	var away: Vector3 = player.global_position - from
	away.y = 0
	player.knock = away.normalized() * 9.0
	player.velocity.y = 5.0
	if lives <= 0:
		_end("lose")

func _end(s: String) -> void:
	state = s
	if s == "win":
		score += lives * 50
		msg.text = "STAGE CLEAR!\nScore: %d\n\nPress R to play again" % score
	else:
		msg.text = "YOU FAILED\nScore: %d\n\nPress R to retry" % score
	player.set_physics_process(false)

func _on_slash(center: Vector3, radius: float) -> void:
	for f in flyers.duplicate():
		var fp: Vector3 = f["node"].global_position
		if fp.distance_to(center) < radius:
			var pts := 20 if f["kind"] == "kunai" else 10
			score += pts
			AudioManager.coin_sfx.play()
			_popup(fp, "+%d" % pts)
			f["node"].queue_free()
			flyers.erase(f)

func _popup(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 120
	l.pixel_size = 0.01
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(1, 0.9, 0.3)
	add_child(l)
	l.global_position = pos
	var tw := create_tween().set_parallel(true)
	tw.tween_property(l, "position:y", pos.y + 1.5, 0.6)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.chain().tween_callback(l.queue_free)

func _spawn_flyer() -> void:
	var dirs := [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1)]
	var d: Vector3 = dirs[randi() % 3]
	var pp: Vector3 = player.global_position
	var lateral := randf_range(-1.5, 1.5)
	var h := pp.y + (1.0 if randf() < 0.6 else 2.0)
	var pos := pp - d * 18.0
	if d.x != 0.0:
		pos.z += lateral
	else:
		pos.x += lateral
	pos.y = h
	var kind := "gold" if randf() < 0.55 else "kunai"
	var n := Node3D.new()
	add_child(n)
	n.global_position = pos
	if kind == "gold":
		var s := SphereMesh.new()
		_mesh(n, s, Color(1, 0.8, 0.1), Vector3.ZERO).scale = Vector3.ONE * 0.9
	else:
		_mesh(n, _box(Vector3(1.1, 0.12, 1.1)), Color(0.9, 0.1, 0.15), Vector3.ZERO)
		var b := _mesh(n, _box(Vector3(1.1, 0.12, 1.1)), Color(0.2, 0.2, 0.25), Vector3.ZERO)
		b.rotation_degrees.y = 45
	flyers.append({"node": n, "vel": d * 7.0, "kind": kind, "life": 6.0})

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventKey and e.pressed and e.physical_keycode == KEY_R:
		get_tree().reload_current_scene()

func _process(dt: float) -> void:
	t += dt
	hud.text = "Score: %d    Lives: %d\nWASD move | Space jump (x2) | Mouse camera | J / Click slash | R restart" % [score, lives]
	if state != "play":
		return
	# blades
	for b in blades:
		var n: Node3D = b["node"]
		n.position = b["base"] + Vector3(sin(t * 1.8 + b["phase"]) * b["amp"], 0, 0)
		if _hit_box(n.global_position, b["half"]):
			_hurt(n.global_position)
	for s in spikes:
		if _hit_box(s["center"], s["half"]):
			_hurt(s["center"])
	# flyers
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = randf_range(1.0, 1.8)
		_spawn_flyer()
	for f in flyers.duplicate():
		var n: Node3D = f["node"]
		n.global_position += f["vel"] * dt
		n.rotation.y += dt * 10.0
		f["life"] -= dt
		var c: Vector3 = player.global_position + Vector3(0, 1.0, 0)
		if f["kind"] == "kunai" and n.global_position.distance_to(c) < 0.9:
			_hurt(n.global_position)
			n.queue_free()
			flyers.erase(f)
		elif f["life"] <= 0.0:
			n.queue_free()
			flyers.erase(f)
	# checkpoint / fall
	var pp: Vector3 = player.global_position
	if player.is_on_floor():
		for p in platforms:
			if absf(pp.x - p["pos"].x) < p["half"].x and absf(pp.z - p["pos"].z) < p["half"].y and absf(pp.y - p["pos"].y) < 0.3:
				checkpoint = p["pos"] + Vector3(0, 1, 0)
	if pp.y < checkpoint.y - 12.0:
		lives -= 1
		player.global_position = checkpoint
		player.velocity = Vector3.ZERO
		player.invincible = 1.5
		if lives <= 0:
			_end("lose")
	if pp.distance_to(goal + Vector3(0, 1, 0)) < 3.5 and player.is_on_floor():
		_end("win")
