extends Node3D
## Fairway Pocket — playable single-hole, low-poly Godot 4.5 web prototype.
## Everything is generated from primitive meshes; no downloaded models needed.

const TEE := Vector3(0.0, 0.24, 23.0)
const CUP := Vector3(0.0, 0.05, -21.0)
const CLUB_NAMES := ["PUTTER", "WEDGE", "IRON", "DRIVER"]
const CLUB_SPEEDS := [9.0, 17.0, 27.0, 39.0]
const CLUB_LOFTS := [0.0, 7.5, 12.0, 16.0]
const PAR := 3

var ball: MeshInstance3D
var aim_line: MeshInstance3D
var ball_shadow: MeshInstance3D
var cam: Camera3D
var speed: Vector3 = Vector3.ZERO
var lift_speed := 0.0
var shot_active := false
var finished := false
var strokes := 0
var aim_degrees := 0.0
var power := 78
var club := 3
var last_lie := TEE

var title_label: Label
var info_label: Label
var instruction_label: Label
var power_label: Label
var club_button: Button

func _ready() -> void:
	_create_environment()
	_create_course()
	_create_ball()
	_create_camera()
	_create_hud()
	_update_aim()
	_update_hud()

func _create_environment() -> void:
	var world := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("#90c7ef")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#eef7ff")
	env.ambient_light_energy = 0.8
	world.environment = env
	add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -25, -15)
	sun.light_energy = 1.25
	add_child(sun)

func _material(color: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.95
	return mat

func _box(dimensions: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := BoxMesh.new()
	shape.size = dimensions
	node.mesh = shape
	node.position = pos
	node.material_override = _material(color)
	add_child(node)
	return node

func _cylinder(radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := CylinderMesh.new()
	shape.top_radius = radius
	shape.bottom_radius = radius
	shape.height = height
	node.mesh = shape
	node.position = pos
	node.material_override = _material(color)
	add_child(node)
	return node

func _sphere(radius: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var node := MeshInstance3D.new()
	var shape := SphereMesh.new()
	shape.radius = radius
	shape.height = radius * 2.0
	node.mesh = shape
	node.position = pos
	node.material_override = _material(color)
	add_child(node)
	return node

func _create_course() -> void:
	# Ground, central fairway, putting green, sand traps, trees and water.
	_box(Vector3(65, 0.16, 95), Vector3(0, -0.15, 0), Color("#356e40"))
	_box(Vector3(14, 0.04, 57), Vector3(0, -0.04, 0), Color("#67ac57"))
	_box(Vector3(8, 0.05, 9), Vector3(0, 0.00, 22.2), Color("#7cba63"))
	_cylinder(9.3, 0.07, Vector3(0, 0.012, -19.0), Color("#95d67a"))
	_cylinder(3.8, 0.055, Vector3(-6.8, 0.005, -9.8), Color("#e9d39b"))
	_cylinder(3.3, 0.055, Vector3(7.5, 0.005, -14.6), Color("#ead69e"))
	_box(Vector3(9.5, 0.02, 17), Vector3(-18, -0.058, -11), Color("#4b9ac7"))
	# Cup, flagstick, flag and 2 tee markers.
	_cylinder(0.46, 0.014, CUP, Color("#192b22"))
	_cylinder(0.045, 3.25, Vector3(CUP.x, 1.67, CUP.z), Color("#f8f8f8"))
	_box(Vector3(1.05, 0.55, 0.025), Vector3(0.56, 2.95, CUP.z), Color("#fa5348"))
	_sphere(0.22, Vector3(-1.3, 0.19, 25), Color("#f9f9ed"))
	_sphere(0.22, Vector3(1.3, 0.19, 25), Color("#f9f9ed"))
	# Decorative shrubs and trees, kept outside fairway.
	var rng := RandomNumberGenerator.new()
	rng.seed = 10828
	for i in range(32):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(12.0, 27.0)
		var z := rng.randf_range(-36.0, 35.0)
		var height := rng.randf_range(1.6, 3.2)
		_cylinder(0.22, height, Vector3(x, height * 0.5, z), Color("#765b3f"))
		_sphere(rng.randf_range(1.15, 1.95), Vector3(x, height + 0.6, z), Color("#276c46") if i % 3 == 0 else Color("#438b51"))
	# Fence-like course boundary.
	for i in range(12):
		var z := -34.0 + float(i) * 6.0
		_box(Vector3(0.13, 0.8, 0.13), Vector3(-31, 0.34, z), Color("#c9dbca"))
		_box(Vector3(0.13, 0.8, 0.13), Vector3(31, 0.34, z), Color("#c9dbca"))

func _create_ball() -> void:
	ball = _sphere(0.24, TEE, Color("#ffffff"))
	ball_shadow = _cylinder(0.30, 0.012, Vector3(TEE.x, 0.034, TEE.z), Color("#2d5634"))
	aim_line = _box(Vector3(0.085, 0.025, 3.5), Vector3.ZERO, Color("#ffe16b"))

func _create_camera() -> void:
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 58
	add_child(cam)
	cam.position = TEE + Vector3(0, 12, 20)
	cam.look_at(TEE + Vector3(0, 0, -9), Vector3.UP)

func _button(caption: String, width: float = 0.0) -> Button:
	var btn := Button.new()
	btn.text = caption
	btn.custom_minimum_size = Vector2(width, 42)
	btn.add_theme_font_size_override("font_size", 14)
	btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return btn

func _create_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(root)

	var upper := VBoxContainer.new()
	upper.offset_left = 18
	upper.offset_top = 12
	upper.offset_right = 430
	upper.offset_bottom = 104
	upper.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(upper)
	title_label = Label.new()
	title_label.text = "FAIRWAY POCKET  |  HOLE 1  •  PAR 3"
	title_label.add_theme_font_size_override("font_size", 23)
	title_label.add_theme_color_override("font_color", Color("#ffffff"))
	upper.add_child(title_label)
	info_label = Label.new()
	info_label.add_theme_font_size_override("font_size", 18)
	info_label.add_theme_color_override("font_color", Color("#ffffff"))
	upper.add_child(info_label)

	var panel := PanelContainer.new()
	panel.anchor_left = 0.0
	panel.anchor_right = 1.0
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_left = 7
	panel.offset_right = -7
	panel.offset_top = -126
	panel.offset_bottom = -7
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.07, 0.19, 0.19, 0.87)
	style.set_corner_radius_all(15)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", style)
	root.add_child(panel)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 5)
	panel.add_child(layout)

	var first := HBoxContainer.new()
	first.add_theme_constant_override("separation", 5)
	layout.add_child(first)
	var left_button := _button("◀ AIM")
	left_button.pressed.connect(func(): _change_aim(-5.0))
	first.add_child(left_button)
	var right_button := _button("AIM ▶")
	right_button.pressed.connect(func(): _change_aim(5.0))
	first.add_child(right_button)
	club_button = _button("CLUB")
	club_button.pressed.connect(_next_club)
	first.add_child(club_button)
	var restart_button := _button("RESET")
	restart_button.pressed.connect(_restart)
	first.add_child(restart_button)

	var second := HBoxContainer.new()
	second.add_theme_constant_override("separation", 5)
	layout.add_child(second)
	var minus_button := _button("−", 48)
	minus_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	minus_button.pressed.connect(func(): _change_power(-5))
	second.add_child(minus_button)
	power_label = Label.new()
	power_label.custom_minimum_size = Vector2(95, 36)
	power_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	power_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	power_label.add_theme_color_override("font_color", Color("#f8f3c6"))
	power_label.add_theme_font_size_override("font_size", 16)
	second.add_child(power_label)
	var plus_button := _button("+", 48)
	plus_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	plus_button.pressed.connect(func(): _change_power(5))
	second.add_child(plus_button)
	var shoot_button := _button("⛳  HIT!", 128)
	shoot_button.pressed.connect(_hit)
	second.add_child(shoot_button)

	instruction_label = Label.new()
	instruction_label.anchor_left = 0
	instruction_label.anchor_right = 1
	instruction_label.anchor_top = 0.5
	instruction_label.anchor_bottom = 0.5
	instruction_label.offset_top = -30
	instruction_label.offset_bottom = 12
	instruction_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	instruction_label.add_theme_color_override("font_color", Color("#ffffff"))
	instruction_label.add_theme_font_size_override("font_size", 16)
	instruction_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(instruction_label)
	instruction_label.text = "Aim at the flag. Select club and power, then HIT!"

func _change_aim(amount: float) -> void:
	if shot_active or finished:
		return
	aim_degrees = clampf(aim_degrees + amount, -70.0, 70.0)
	_update_aim()
	_update_hud()

func _change_power(amount: int) -> void:
	if shot_active or finished:
		return
	power = clampi(power + amount, 5, 100)
	_update_hud()

func _next_club() -> void:
	if shot_active or finished:
		return
	club = (club + 1) % CLUB_NAMES.size()
	_update_hud()

func _hit() -> void:
	if shot_active or finished:
		return
	last_lie = ball.position
	strokes += 1
	var angle := deg_to_rad(aim_degrees)
	var amount: float = float(power) / 100.0
	var direction := Vector3(sin(angle), 0, -cos(angle))
	speed = direction * float(CLUB_SPEEDS[club]) * amount
	lift_speed = float(CLUB_LOFTS[club]) * amount
	shot_active = true
	instruction_label.text = "Ball in motion..."
	aim_line.visible = false
	_update_hud()

func _restart() -> void:
	ball.position = TEE
	speed = Vector3.ZERO
	lift_speed = 0.0
	shot_active = false
	finished = false
	strokes = 0
	power = 78
	club = 3
	aim_degrees = 0.0
	instruction_label.text = "New round. Aim, choose power, then HIT!"
	aim_line.visible = true
	_update_aim()
	_update_hud()

func _update_aim() -> void:
	if not is_instance_valid(aim_line):
		return
	var angle := deg_to_rad(aim_degrees)
	var direction := Vector3(sin(angle), 0, -cos(angle))
	aim_line.position = Vector3(ball.position.x, 0.12, ball.position.z) + direction * 2.1
	aim_line.rotation.y = -angle

func _update_hud() -> void:
	if not is_instance_valid(info_label):
		return
	var distance := Vector2(ball.position.x, ball.position.z).distance_to(Vector2(CUP.x, CUP.z))
	info_label.text = "SHOTS: %d   •   TO FLAG: %.1f m   •   AIM: %d°" % [strokes, distance, int(aim_degrees)]
	power_label.text = "POWER %d%%" % power
	club_button.text = "CLUB: " + CLUB_NAMES[club]

func _process(delta: float) -> void:
	if shot_active:
		_move_ball(minf(delta, 0.05))
	var cam_target := ball.position + Vector3(0, 12, 20)
	cam.position = cam.position.lerp(cam_target, minf(delta * 2.5, 1.0))
	cam.look_at(ball.position + Vector3(0, 0, -9), Vector3.UP)
	ball_shadow.position = Vector3(ball.position.x, 0.04, ball.position.z)

func _move_ball(delta: float) -> void:
	ball.position += speed * delta
	if ball.position.y > 0.24 or lift_speed > 0.0:
		ball.position.y += lift_speed * delta
		lift_speed -= 22.0 * delta
		speed *= pow(0.992, delta * 60.0)
		if ball.position.y <= 0.24:
			ball.position.y = 0.24
			if lift_speed < -2.2:
				lift_speed = -lift_speed * 0.29
			else:
				lift_speed = 0.0
	else:
		ball.position.y = 0.24
		var friction := 0.963
		if absf(ball.position.x) > 7.0:
			friction = 0.930
		if Vector2(ball.position.x + 6.8, ball.position.z + 9.8).length() < 3.8:
			friction = 0.83
		if Vector2(ball.position.x - 7.5, ball.position.z + 14.6).length() < 3.3:
			friction = 0.83
		speed *= pow(friction, delta * 60.0)
	# Simplified cup capture at low approach speed.
	var flat_distance := Vector2(ball.position.x, ball.position.z).distance_to(Vector2(CUP.x, CUP.z))
	if flat_distance < 0.58 and ball.position.y < 0.65 and speed.length() < 8.0:
		finished = true
		shot_active = false
		ball.position = Vector3(CUP.x, 0.05, CUP.z)
		speed = Vector3.ZERO
		instruction_label.text = "HOLED OUT!  %d STROKES  •  PAR %d   |   RESET to play again" % [strokes, PAR]
		_update_hud()
		return
	if absf(ball.position.x) > 30.0 or absf(ball.position.z) > 44.0:
		ball.position = last_lie
		speed = Vector3.ZERO
		lift_speed = 0.0
		shot_active = false
		strokes += 1 # Out-of-bounds penalty.
		instruction_label.text = "Out of bounds! +1 penalty stroke."
		aim_line.visible = true
		_update_aim()
		_update_hud()
		return
	if speed.length() < 0.13 and lift_speed == 0.0 and ball.position.y <= 0.241:
		shot_active = false
		speed = Vector3.ZERO
		instruction_label.text = "Ball stopped. Aim and hit the next shot."
		aim_line.visible = true
		_update_aim()
	_update_hud()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_LEFT, KEY_A:
				_change_aim(-3.0)
			KEY_RIGHT, KEY_D:
				_change_aim(3.0)
			KEY_UP, KEY_W:
				_change_power(5)
			KEY_DOWN, KEY_S:
				_change_power(-5)
			KEY_SPACE:
				_hit()
			KEY_TAB:
				_next_club()
	if event is InputEventScreenDrag and not shot_active and not finished:
		if absf(event.relative.x) > 2.0:
			_change_aim(float(event.relative.x) * 0.12)
