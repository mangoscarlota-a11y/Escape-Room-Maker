extends CharacterBody3D
## Jugador en primera persona. Se construye solo por código (cápsula, cámara, rayo, HUD).

signal menu_requested

const SPEED := 4.0
const SPRINT_SPEED := 6.5
const JUMP_VELOCITY := 4.2
const MOUSE_SENS := 0.0025
const REACH := 2.5

var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity")

var head: Node3D
var camera: Camera3D
var ray: RayCast3D
var prompt_label: Label
var msg_label: Label

var _target: Object = null
var _msg_id := 0

var inventory: Array[String] = []
var inv_label: Label
var _left := false


func _ready() -> void:
	_setup_inputs()

	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.75
	col.shape = cap
	col.position.y = 0.875
	add_child(col)

	head = Node3D.new()
	head.position.y = 1.6
	add_child(head)

	camera = Camera3D.new()
	camera.fov = 75.0
	head.add_child(camera)

	ray = RayCast3D.new()
	ray.target_position = Vector3(0, 0, -REACH)
	camera.add_child(ray)
	ray.add_exception(self)
	ray.collision_mask = 3 # capa 1: objetos sólidos; capa 2: objetos pequeños que no bloquean

	_build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _setup_inputs() -> void:
	var keys := {
		"move_forward": KEY_W,
		"move_back": KEY_S,
		"move_left": KEY_A,
		"move_right": KEY_D,
		"jump": KEY_SPACE,
		"sprint": KEY_SHIFT,
		"interact": KEY_E,
		"menu": KEY_M,
	}
	for action in keys:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
			var ev := InputEventKey.new()
			ev.physical_keycode = keys[action]
			InputMap.action_add_event(action, ev)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		rotate_y(-event.relative.x * MOUSE_SENS)
		head.rotate_x(-event.relative.y * MOUSE_SENS)
		head.rotation.x = clamp(head.rotation.x, deg_to_rad(-85.0), deg_to_rad(85.0))
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event.is_action_pressed("menu"):
		menu_requested.emit()
	elif event.is_action_pressed("interact") and _target != null and is_instance_valid(_target):
		_target.interact(self)


func _physics_process(delta: float) -> void:
	if is_on_floor():
		if Input.is_action_just_pressed("jump"):
			velocity.y = JUMP_VELOCITY
	else:
		velocity.y -= gravity * delta

	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else SPEED
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var dir := (global_transform.basis * Vector3(input_dir.x, 0, input_dir.y)).normalized()
	var weight := clampf((12.0 if is_on_floor() else 3.0) * delta, 0.0, 1.0)
	velocity.x = lerpf(velocity.x, dir.x * speed, weight)
	velocity.z = lerpf(velocity.z, dir.z * speed, weight)

	move_and_slide()
	_update_target()

	# Si sales por la puerta y caes al vacío, termina la partida.
	if global_position.y < -6.0 and not _left:
		_left = true
		menu_requested.emit()


func _update_target() -> void:
	_target = null
	if ray.is_colliding():
		var c = ray.get_collider()
		if c != null and c.has_method("interact"):
			_target = c
	if _target != null:
		prompt_label.text = "[E] " + str(_target.get("prompt_text"))
	else:
		prompt_label.text = ""


## Muestra un mensaje temporal en pantalla.
func show_message(text: String, seconds := 2.5) -> void:
	_msg_id += 1
	var id := _msg_id
	msg_label.text = text
	await get_tree().create_timer(seconds).timeout
	if id == _msg_id:
		msg_label.text = ""


## --- Inventario ---
func add_item(item: String) -> void:
	inventory.append(item)
	_update_inventory_hud()


func has_item(item: String) -> bool:
	return inventory.has(item)


func remove_item(item: String) -> void:
	inventory.erase(item)
	_update_inventory_hud()


func _update_inventory_hud() -> void:
	if inventory.is_empty():
		inv_label.text = "Inventario: (vacío)"
	else:
		inv_label.text = "Inventario: " + ", ".join(inventory)


func _build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.85)
	dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	dot.set_anchors_preset(Control.PRESET_CENTER)
	dot.offset_left = -2
	dot.offset_right = 2
	dot.offset_top = -2
	dot.offset_bottom = 2
	layer.add_child(dot)

	prompt_label = _make_label(layer, 30)
	msg_label = _make_label(layer, 90)

	inv_label = Label.new()
	inv_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	inv_label.add_theme_font_size_override("font_size", 18)
	inv_label.add_theme_color_override("font_outline_color", Color.BLACK)
	inv_label.add_theme_constant_override("outline_size", 6)
	inv_label.position = Vector2(16, 16)
	layer.add_child(inv_label)
	_update_inventory_hud()

	var hint := Label.new()
	hint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint.text = "E: interactuar · M: menú · Esc: soltar ratón"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 4)
	hint.position = Vector2(16, 46)
	layer.add_child(hint)


func _make_label(layer: CanvasLayer, y: float) -> Label:
	var l := Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.set_anchors_preset(Control.PRESET_CENTER)
	l.offset_left = -300
	l.offset_right = 300
	l.offset_top = y
	l.offset_bottom = y + 30
	layer.add_child(l)
	return l
