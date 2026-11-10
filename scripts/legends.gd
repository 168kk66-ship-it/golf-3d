extends Node3D
## FAIRWAY LEGENDS: original, lightweight arcade prototype.
## Three playable modes. All geometry and UI are procedurally created.
## Modes are original prototypes; they do not use Siam Slam assets or code.

const TEE := Vector3(0.0, 0.25, 23.0)
const HOLE := Vector3(0.0, 0.035, -22.0)
const CLUB_NAMES := ["PUTTER", "WEDGE", "IRON", "DRIVER"]
const CLUB_SPEEDS := [10.0, 19.0, 31.0, 46.0]
const CLUB_LOFT := [0.0, 8.0, 13.0, 18.0]
const GOLD := Color("#f4cc76")
const SKY := Color("#a7d8f4")
const WHITE := Color("#f5fbfa")
const GREEN := Color("#4aaf78")
const DARK := Color("#112c34")

var mode := "menu" # menu, golf, defense, faction
var phase := "ready" # ready, power, accuracy, flying, done
var rng := RandomNumberGenerator.new()
var world_root: Node3D
var cam: Camera3D
var ball: MeshInstance3D
var aim_guide: MeshInstance3D
var velocity := Vector3.ZERO
var power_percentage := 60.0
var accuracy_value := 0.0
var meter_time := 0.0
var aim_degrees := 0.0
var club_index := 3
var spin_index := 0 # -1 backspin, 0 neutral, 1 topspin
var wind := Vector2.ZERO
var shots := 0
var stroke_limit := 12
var last_lie := TEE
var defense_lives := 5
var defense_kills := 0
var spawn_clock := 0.0
var enemies: Array[Dictionary] = []
var faction_round := 0
var blue_points := 0
var red_points := 0

var hud_top: PanelContainer
var hud_bottom: PanelContainer
var menu_panel: PanelContainer
var title_label: Label
var status_label: Label
var hint_label: Label
var swing_button: Button
var club_button: Button
var spin_button: Button
var meter: ProgressBar
var meter_label: Label

func _ready() -> void:
	rng.seed = 20261110
	_create_environment()
	_create_camera()
	_create_ui()
	_create_course("golf")
	_open_menu()

func _create_environment() -> void:
	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = SKY
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#e3f0ed")
	env.ambient_light_energy = 0.85
	env_node.environment = env
	add_child(env_node)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-58.0, -30.0, 4.0)
	sun.light_energy = 1.35
	add_child(sun)

func _create_camera() -> void:
	cam = Camera3D.new()
	cam.current = true
	cam.fov = 62.0
	add_child(cam)
	cam.position = Vector3(0, 15, 39)
	cam.look_at(Vector3(0, 0, -8), Vector3.UP)

func _material(c: Color) -> StandardMaterial3D:
	var mat := StandardMaterial3D.new()
	mat.albedo_color = c
	mat.roughness = 0.88
	return mat

func _box(parent: Node3D, sz: Vector3, p: Vector3, c: Color) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = sz
	obj.mesh = mesh
	obj.position = p
	obj.material_override = _material(c)
	parent.add_child(obj)
	return obj

func _sphere(parent: Node3D, radius: float, p: Vector3, c: Color) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	obj.mesh = mesh
	obj.position = p
	obj.material_override = _material(c)
	parent.add_child(obj)
	return obj

func _cylinder(parent: Node3D, radius: float, height: float, p: Vector3, c: Color) -> MeshInstance3D:
	var obj := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	obj.mesh = mesh
	obj.position = p
	obj.material_override = _material(c)
	parent.add_child(obj)
	return obj

func _create_course(for_mode: String) -> void:
	if is_instance_valid(world_root):
		world_root.queue_free()
	world_root = Node3D.new()
	add_child(world_root)
	_box(world_root, Vector3(70, 0.18, 105), Vector3(0, -0.15, -1), Color("#315f47"))
	_box(world_root, Vector3(15, 0.035, 74), Vector3(0, -0.025, -3), Color("#62a960"))
	_box(world_root, Vector3(10, 0.04, 10), Vector3(0, 0.008, 22), Color("#8dc47e"))
	_cylinder(world_root, 9.0, 0.055, Vector3(0, 0.018, -21), Color("#93d77c"))
	# Sand hazards and a small ornamental pond.
	_cylinder(world_root, 4.1, 0.05, Vector3(-7.5, 0.018, -10), Color("#ebd6a3"))
	_cylinder(world_root, 3.2, 0.05, Vector3(7.0, 0.018, -16), Color("#ebd6a3"))
	_box(world_root, Vector3(8, 0.025, 18), Vector3(-19, -0.04, -14), Color("#4e9cbd"))
	for i in range(28):
		var side := -1.0 if i % 2 == 0 else 1.0
		var x := side * rng.randf_range(12, 31)
		var z := rng.randf_range(-39, 38)
		var h := rng.randf_range(1.9, 3.4)
		_cylinder(world_root, 0.21, h, Vector3(x, h * 0.5, z), Color("#785b41"))
		_sphere(world_root, rng.randf_range(1.1, 1.8), Vector3(x, h + 0.55, z), Color("#2b7150") if i % 3 == 0 else Color("#4a9563"))
	# Hole + flag.
	_cylinder(world_root, 0.48, 0.014, HOLE, Color("#23332b"))
	_cylinder(world_root, 0.052, 3.7, Vector3(0, 1.9, HOLE.z), WHITE)
	_box(world_root, Vector3(1.25, 0.72, 0.035), Vector3(0.66, 3.29, HOLE.z), Color("#e4534d"))
	# Tee markers.
	_sphere(world_root, 0.22, Vector3(-1.5, 0.23, 25.4), GOLD)
	_sphere(world_root, 0.22, Vector3(1.5, 0.23, 25.4), GOLD)
	if for_mode == "faction":
		# Original faction capture target: concentric rings.
		_cylinder(world_root, 7.3, 0.02, Vector3(0, 0.063, -21), Color("#4e96c7"))
		_cylinder(world_root, 5.1, 0.024, Vector3(0, 0.077, -21), Color("#e4d7a1"))
		_cylinder(world_root, 2.6, 0.03, Vector3(0, 0.092, -21), Color("#6acb93"))
	if for_mode == "defense":
		for lane in [-6.0, 0.0, 6.0]:
			_box(world_root, Vector3(0.16, 0.06, 50), Vector3(lane, 0.08, -2), Color("#c7bb82"))
		for x in [-8.3, 8.3]:
			_box(world_root, Vector3(1.5, 5, 1.5), Vector3(x, 2.5, 24.0), Color("#c9bc9e"))
			_box(world_root, Vector3(2, 0.5, 2), Vector3(x, 5.2, 24), Color("#b48868"))
	ball = _sphere(world_root, 0.25, TEE, WHITE)
	aim_guide = _box(world_root, Vector3(0.085, 0.025, 4.6), Vector3.ZERO, GOLD)
	_update_guide()

func _panel_style(color: Color, border: Color, radius: int = 17) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.border_color = border
	s.set_border_width_all(2)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 10
	s.content_margin_bottom = 10
	s.shadow_color = Color(0, 0, 0, 0.24)
	s.shadow_size = 7
	s.shadow_offset = Vector2(0, 3)
	return s

func _button(label_text: String, color: Color, border: Color) -> Button:
	var b := Button.new()
	b.text = label_text
	b.custom_minimum_size = Vector2(0, 46)
	b.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", WHITE)
	b.add_theme_color_override("font_hover_color", WHITE)
	b.add_theme_color_override("font_pressed_color", WHITE)
	b.add_theme_stylebox_override("normal", _panel_style(color, border, 12))
	b.add_theme_stylebox_override("hover", _panel_style(color.lightened(0.16), border.lightened(0.1), 12))
	b.add_theme_stylebox_override("pressed", _panel_style(color.darkened(0.19), border, 12))
	b.add_theme_stylebox_override("disabled", _panel_style(Color("#546368"), Color("#778387"), 12))
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	return b

func _create_ui() -> void:
	var canvas := CanvasLayer.new()
	add_child(canvas)
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(root)

	hud_top = PanelContainer.new()
	hud_top.anchor_left = 0
	hud_top.anchor_right = 1
	hud_top.anchor_top = 0
	hud_top.anchor_bottom = 0
	hud_top.offset_left = 10
	hud_top.offset_right = -10
	hud_top.offset_top = 9
	hud_top.offset_bottom = 81
	hud_top.add_theme_stylebox_override("panel", _panel_style(Color(0.06, 0.17, 0.19, 0.89), GOLD))
	root.add_child(hud_top)
	var top_vbox := VBoxContainer.new()
	hud_top.add_child(top_vbox)
	title_label = Label.new()
	title_label.text = "FAIRWAY LEGENDS"
	title_label.add_theme_font_size_override("font_size", 21)
	title_label.add_theme_color_override("font_color", GOLD)
	top_vbox.add_child(title_label)
	status_label = Label.new()
	status_label.add_theme_font_size_override("font_size", 15)
	status_label.add_theme_color_override("font_color", WHITE)
	top_vbox.add_child(status_label)

	hint_label = Label.new()
	hint_label.anchor_left = 0.06
	hint_label.anchor_right = 0.94
	hint_label.anchor_top = 0.48
	hint_label.anchor_bottom = 0.48
	hint_label.offset_top = -22
	hint_label.offset_bottom = 24
	hint_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.add_theme_color_override("font_color", WHITE)
	hint_label.add_theme_font_size_override("font_size", 15)
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(hint_label)

	hud_bottom = PanelContainer.new()
	hud_bottom.anchor_left = 0
	hud_bottom.anchor_right = 1
	hud_bottom.anchor_top = 1
	hud_bottom.anchor_bottom = 1
	hud_bottom.offset_left = 10
	hud_bottom.offset_right = -10
	hud_bottom.offset_top = -155
	hud_bottom.offset_bottom = -9
	hud_bottom.add_theme_stylebox_override("panel", _panel_style(Color(0.055, 0.14, 0.17, 0.94), Color("#7bcfa4")))
	root.add_child(hud_bottom)
	var controls := VBoxContainer.new()
	controls.add_theme_constant_override("separation", 5)
	hud_bottom.add_child(controls)
	var row_one := HBoxContainer.new()
	row_one.add_theme_constant_override("separation", 5)
	controls.add_child(row_one)
	var left := _button("◀ AIM", Color("#285e83"), Color("#8ad7fc"))
	left.pressed.connect(func(): _adjust_aim(-4.0))
	row_one.add_child(left)
	var right := _button("AIM ▶", Color("#285e83"), Color("#8ad7fc"))
	right.pressed.connect(func(): _adjust_aim(4.0))
	row_one.add_child(right)
	club_button = _button("DRIVER", Color("#71542f"), GOLD)
	club_button.pressed.connect(_switch_club)
	row_one.add_child(club_button)
	spin_button = _button("SPIN: 0", Color("#3b6450"), Color("#9dddab"))
	spin_button.pressed.connect(_switch_spin)
	row_one.add_child(spin_button)
	var home := _button("MENU", Color("#713e4d"), Color("#dfa2ac"))
	home.pressed.connect(_open_menu)
	row_one.add_child(home)

	var row_two := HBoxContainer.new()
	row_two.add_theme_constant_override("separation", 9)
	controls.add_child(row_two)
	var meter_box := VBoxContainer.new()
	meter_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row_two.add_child(meter_box)
	meter_label = Label.new()
	meter_label.text = "READY"
	meter_label.add_theme_color_override("font_color", GOLD)
	meter_label.add_theme_font_size_override("font_size", 14)
	meter_box.add_child(meter_label)
	meter = ProgressBar.new()
	meter.min_value = 0
	meter.max_value = 100
	meter.value = 60
	meter.show_percentage = false
	meter.custom_minimum_size = Vector2(110, 26)
	meter.add_theme_stylebox_override("background", _panel_style(Color("#203f47"), Color("#417079"), 6))
	meter.add_theme_stylebox_override("fill", _panel_style(Color("#e0a65b"), GOLD, 6))
	meter_box.add_child(meter)
	swing_button = _button("START SWING", Color("#ae7139"), Color("#ffd589"))
	swing_button.custom_minimum_size = Vector2(164, 60)
	swing_button.pressed.connect(_press_swing)
	row_two.add_child(swing_button)

	menu_panel = PanelContainer.new()
	menu_panel.anchor_left = 0.14
	menu_panel.anchor_right = 0.86
	menu_panel.anchor_top = 0.14
	menu_panel.anchor_bottom = 0.88
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.045, 0.12, 0.15, 0.98), GOLD, 22))
	root.add_child(menu_panel)
	var menu_vbox := VBoxContainer.new()
	menu_vbox.alignment = BoxContainer.ALIGNMENT_CENTER
	menu_vbox.add_theme_constant_override("separation", 12)
	menu_panel.add_child(menu_vbox)
	var hero := Label.new()
	hero.text = "FAIRWAY LEGENDS"
	hero.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hero.add_theme_color_override("font_color", GOLD)
	hero.add_theme_font_size_override("font_size", 29)
	menu_vbox.add_child(hero)
	var sub := Label.new()
	sub.text = "3 ORIGINAL ARCADE MODES"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_color_override("font_color", WHITE)
	sub.add_theme_font_size_override("font_size", 15)
	menu_vbox.add_child(sub)
	var golf_button := _button("⛳  WARRIOR GOLF", Color("#23704f"), Color("#88ddb0"))
	golf_button.pressed.connect(func(): _start_mode("golf"))
	menu_vbox.add_child(golf_button)
	var defense_button := _button("🏰  KINGDOM DEFENSE", Color("#8d5f37"), GOLD)
	defense_button.pressed.connect(func(): _start_mode("defense"))
	menu_vbox.add_child(defense_button)
	var faction_button := _button("⚔  FACTION WAR", Color("#3c5e92"), Color("#9ecbff"))
	faction_button.pressed.connect(func(): _start_mode("faction"))
	menu_vbox.add_child(faction_button)
	var note := Label.new()
	note.text = "Tap 3 times: start meter → lock power → time accuracy.\nOriginal prototype • no third-party art or code"
	note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note.add_theme_color_override("font_color", Color("#c9ddd5"))
	note.add_theme_font_size_override("font_size", 12)
	menu_vbox.add_child(note)

func _open_menu() -> void:
	mode = "menu"
	phase = "ready"
	hud_top.visible = false
	hud_bottom.visible = false
	hint_label.visible = false
	menu_panel.visible = true

func _start_mode(next_mode: String) -> void:
	mode = next_mode
	phase = "ready"
	shots = 0
	aim_degrees = 0
	club_index = 3 if mode == "golf" else 2
	spin_index = 0
	wind = Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-0.7, 0.7))
	velocity = Vector3.ZERO
	defense_lives = 5
	defense_kills = 0
	spawn_clock = 0.5
	enemies.clear()
	faction_round = 0
	blue_points = 0
	red_points = 0
	power_percentage = 65.0
	accuracy_value = 0.0
	_create_course(mode)
	last_lie = TEE
	hud_top.visible = true
	hud_bottom.visible = true
	hint_label.visible = true
	menu_panel.visible = false
	if mode == "golf":
		hint_label.text = "HOLE 1  •  PAR 3  |  Reach the flag in fewest strokes"
	elif mode == "defense":
		hint_label.text = "DEFEND THE GATE  •  Aim at approaching enemies"
	else:
		hint_label.text = "BLUE vs RED BOT  •  Land inside target rings for points"
	_refresh_ui()

func _adjust_aim(amount: float) -> void:
	if phase != "ready":
		return
	aim_degrees = clampf(aim_degrees + amount, -72.0, 72.0)
	_update_guide()
	_refresh_ui()

func _switch_club() -> void:
	if phase != "ready":
		return
	club_index = (club_index + 1) % CLUB_NAMES.size()
	_refresh_ui()

func _switch_spin() -> void:
	if phase != "ready":
		return
	spin_index += 1
	if spin_index > 1:
		spin_index = -1
	_refresh_ui()

func _update_guide() -> void:
	if not is_instance_valid(aim_guide) or not is_instance_valid(ball):
		return
	var angle := deg_to_rad(aim_degrees)
	var dir := Vector3(sin(angle), 0, -cos(angle))
	aim_guide.position = Vector3(ball.position.x, 0.14, ball.position.z) + dir * 2.65
	aim_guide.rotation.y = -angle

func _press_swing() -> void:
	if mode == "menu" or phase == "done" or phase == "flying":
		return
	if phase == "ready":
		phase = "power"
		meter_time = 0
		hint_label.text = "Tap again to LOCK POWER!"
	elif phase == "power":
		phase = "accuracy"
		meter_time = 0
		hint_label.text = "Tap near the CENTER for a perfect shot!"
	elif phase == "accuracy":
		_launch()
	_refresh_ui()

func _launch() -> void:
	phase = "flying"
	shots += 1
	last_lie = ball.position
	var deviation := accuracy_value * 0.23
	var angle := deg_to_rad(aim_degrees + deviation)
	var dir := Vector3(sin(angle), 0, -cos(angle))
	var strength := maxf(0.10, power_percentage / 100.0)
	velocity = dir * float(CLUB_SPEEDS[club_index]) * strength
	velocity.y = float(CLUB_LOFT[club_index]) * strength
	if mode == "defense":
		velocity *= 1.05
	aim_guide.visible = false
	hint_label.text = "SHOT IN FLIGHT"
	_refresh_ui()

func _process(delta: float) -> void:
	var dt := minf(delta, 0.05)
	if mode == "menu":
		cam.position = cam.position.lerp(Vector3(0, 16, 40), minf(dt * 1.6, 1.0))
		cam.look_at(Vector3(0, 0, -10), Vector3.UP)
		return
	if phase == "power":
		meter_time += dt
		power_percentage = 15.0 + 85.0 * absf(sin(meter_time * 2.25))
	elif phase == "accuracy":
		meter_time += dt
		accuracy_value = sin(meter_time * 3.1) * 100.0
	if phase == "flying":
		_simulate_ball(dt)
	if mode == "defense" and phase != "done":
		_update_defense(dt)
	if is_instance_valid(ball):
		var target := ball.position + Vector3(0, 13, 20)
		cam.position = cam.position.lerp(target, minf(dt * 2.2, 1.0))
		cam.look_at(ball.position + Vector3(0, 0, -11), Vector3.UP)
	_refresh_ui()

func _simulate_ball(dt: float) -> void:
	if not is_instance_valid(ball):
		return
	ball.position += velocity * dt
	var airborne := ball.position.y > 0.251 or velocity.y > 0.0
	if airborne:
		velocity.y -= 21.0 * dt
		velocity.x += wind.x * 0.55 * dt
		velocity.z += wind.y * 0.25 * dt
		velocity.x *= pow(0.997, dt * 60.0)
		velocity.z *= pow(0.997, dt * 60.0)
		if ball.position.y <= 0.25:
			ball.position.y = 0.25
			if velocity.y < -3.0:
				velocity.y = -velocity.y * 0.23
			else:
				velocity.y = 0.0
	else:
		ball.position.y = 0.25
		velocity.y = 0.0
		var damp := 0.961
		if absf(ball.position.x) > 8.0:
			damp = 0.924
		if Vector2(ball.position.x + 7.5, ball.position.z + 10).length() < 4.1:
			damp = 0.82
		if Vector2(ball.position.x - 7.0, ball.position.z + 16).length() < 3.2:
			damp = 0.82
		damp += float(spin_index) * 0.009
		velocity.x *= pow(damp, dt * 60.0)
		velocity.z *= pow(damp, dt * 60.0)
	if mode == "defense":
		for i in range(enemies.size() - 1, -1, -1):
			var foe := enemies[i]["node"] as Node3D
			if is_instance_valid(foe):
				var flat_distance := Vector2(ball.position.x, ball.position.z).distance_to(Vector2(foe.position.x, foe.position.z))
				if flat_distance < 1.8 and ball.position.y < 5.5:
					foe.queue_free()
					enemies.remove_at(i)
					defense_kills += 1
					_reset_ball_to_tee()
					if defense_kills >= 10:
						_finish("VICTORY!  CASTLE SAVED  •  10 enemies defeated")
					else:
						hint_label.text = "DIRECT HIT!  Protect the gate!"
					return
	if mode == "golf" and ball.position.y < 0.85:
		var dist := Vector2(ball.position.x, ball.position.z).distance_to(Vector2(HOLE.x, HOLE.z))
		if dist < 0.74 and Vector2(velocity.x, velocity.z).length() < 10.0:
			velocity = Vector3.ZERO
			ball.position = Vector3(HOLE.x, 0.10, HOLE.z)
			_finish("HOLED OUT!  %d STROKES  •  PAR 3" % shots)
			return
	if absf(ball.position.x) > 34.0 or absf(ball.position.z) > 48.0:
		if mode == "golf":
			shots += 1
			ball.position = last_lie
			_ready_again("OUT OF BOUNDS!  +1 PENALTY")
		elif mode == "defense":
			_reset_ball_to_tee()
			hint_label.text = "MISSED!  The enemies are still moving!"
		else:
			_score_faction()
		return
	if velocity.length() < 0.18 and ball.position.y <= 0.251:
		if mode == "golf":
			_ready_again("BALL STOPPED  •  Aim and swing again")
			if shots >= stroke_limit:
				_finish("HOLE COMPLETE  •  MAXIMUM SHOTS REACHED")
		elif mode == "defense":
			_reset_ball_to_tee()
			hint_label.text = "MISS  •  Aim for the moving soldiers"
		else:
			_score_faction()

func _ready_again(message: String) -> void:
	velocity = Vector3.ZERO
	phase = "ready"
	aim_guide.visible = true
	_update_guide()
	hint_label.text = message

func _reset_ball_to_tee() -> void:
	velocity = Vector3.ZERO
	ball.position = TEE
	aim_degrees = 0
	phase = "ready"
	aim_guide.visible = true
	_update_guide()

func _spawn_enemy() -> void:
	var lanes := [-6.0, 0.0, 6.0]
	var lane: float = float(lanes[rng.randi_range(0, 2)])
	var foe := Node3D.new()
	foe.position = Vector3(lane, 0, -37)
	world_root.add_child(foe)
	_box(foe, Vector3(0.9, 1.5, 0.8), Vector3(0, 0.8, 0), Color("#b65045"))
	_sphere(foe, 0.55, Vector3(0, 1.9, 0), Color("#d6b787"))
	_box(foe, Vector3(1.1, 0.24, 0.25), Vector3(0, 2.48, 0), Color("#a6a6aa"))
	enemies.append({"node": foe, "speed": rng.randf_range(1.2, 2.4)})

func _update_defense(dt: float) -> void:
	spawn_clock -= dt
	if spawn_clock <= 0.0 and enemies.size() < 7:
		_spawn_enemy()
		spawn_clock = rng.randf_range(1.7, 3.1)
	for i in range(enemies.size() - 1, -1, -1):
		var foe := enemies[i]["node"] as Node3D
		if not is_instance_valid(foe):
			enemies.remove_at(i)
			continue
		foe.position.z += float(enemies[i]["speed"]) * dt
		if foe.position.z >= 22.0:
			foe.queue_free()
			enemies.remove_at(i)
			defense_lives -= 1
			hint_label.text = "THE GATE TOOK DAMAGE!  Keep firing!"
			if defense_lives <= 0:
				_finish("DEFEAT  •  THE KINGDOM HAS FALLEN")
				return

func _score_faction() -> void:
	var dist := Vector2(ball.position.x, ball.position.z).distance_to(Vector2(0, -21))
	var earned := 0
	if dist < 2.6:
		earned = 5
	elif dist < 5.1:
		earned = 3
	elif dist < 7.3:
		earned = 1
	blue_points += earned
	red_points += rng.randi_range(0, 4)
	faction_round += 1
	_reset_ball_to_tee()
	if faction_round >= 5:
		var verdict := "YOU WIN!" if blue_points > red_points else ("DRAW!" if blue_points == red_points else "RED BOT WINS!")
		_finish("%s  •  BLUE %d : RED %d" % [verdict, blue_points, red_points])
	else:
		hint_label.text = "ROUND %d/5  •  YOU EARNED %d POINTS" % [faction_round, earned]

func _finish(message: String) -> void:
	phase = "done"
	velocity = Vector3.ZERO
	aim_guide.visible = false
	hint_label.text = message

func _refresh_ui() -> void:
	if mode == "menu":
		return
	var mode_text := "WARRIOR GOLF"
	if mode == "defense":
		mode_text = "KINGDOM DEFENSE"
	elif mode == "faction":
		mode_text = "FACTION WAR"
	title_label.text = "FAIRWAY LEGENDS   /   " + mode_text
	if mode == "golf":
		var distance := Vector2(ball.position.x, ball.position.z).distance_to(Vector2(HOLE.x, HOLE.z))
		status_label.text = "PAR 3  •  SHOTS %d  •  FLAG %.1fm  •  WIND %.1f  •  AIM %d°" % [shots, distance, wind.length(), int(aim_degrees)]
	elif mode == "defense":
		status_label.text = "GATE HP %d/5  •  KILLS %d/10  •  SHOTS %d  •  AIM %d°" % [defense_lives, defense_kills, shots, int(aim_degrees)]
	else:
		status_label.text = "ROUND %d/5  •  BLUE %d  :  RED BOT %d  •  AIM %d°" % [mini(faction_round + 1, 5), blue_points, red_points, int(aim_degrees)]
	club_button.text = CLUB_NAMES[club_index]
	spin_button.text = "SPIN %d" % spin_index
	swing_button.disabled = phase == "flying" or phase == "done"
	if phase == "ready":
		swing_button.text = "START SWING"
		meter.value = power_percentage
		meter_label.text = "READY  •  3 TAP SHOT"
	elif phase == "power":
		swing_button.text = "LOCK POWER"
		meter.value = power_percentage
		meter_label.text = "POWER %d%%  •  TAP TO LOCK" % int(power_percentage)
	elif phase == "accuracy":
		swing_button.text = "HIT PERFECT!"
		meter.value = (accuracy_value + 100.0) * 0.5
		meter_label.text = "ACCURACY %d  •  CENTER = PERFECT" % int(absf(accuracy_value))
	elif phase == "flying":
		swing_button.text = "BALL FLYING..."
		meter.value = power_percentage
		meter_label.text = "SHOT IN FLIGHT"
	else:
		swing_button.text = "ROUND FINISHED"
		meter.value = 100
		meter_label.text = "RETURN TO MENU"

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		match event.keycode:
			KEY_SPACE, KEY_ENTER:
				if mode != "menu":
					_press_swing()
			KEY_LEFT, KEY_A:
				_adjust_aim(-4.0)
			KEY_RIGHT, KEY_D:
				_adjust_aim(4.0)
			KEY_TAB:
				_switch_club()
			KEY_ESCAPE:
				_open_menu()
