extends Node3D
## Menú principal y cambio entre modos: tutorial, creador y jugar salas guardadas.

const RoomBuilder = preload("res://room_builder.gd")
const PlayerScript = preload("res://player.gd")
const Shell = preload("res://shell.gd")
const Catalog = preload("res://catalog.gd")
const RoomData = preload("res://room_data.gd")
const Creator = preload("res://creator.gd")
const OnlineScript = preload("res://online.gd")

var scene_root: Node3D = null
var menu_layer: CanvasLayer = null
var return_to_creator := false
var last_data: Dictionary = {}
var online: OnlineScript = null


func _ready() -> void:
	online = OnlineScript.new()
	add_child(online)
	show_menu()


# ------------------------------------------------------------------ utilidades

func _clear() -> void:
	if scene_root != null:
		scene_root.queue_free()
		scene_root = null
	if menu_layer != null:
		menu_layer.queue_free()
		menu_layer = null


func _new_container(bright: bool) -> Node3D:
	_clear()
	scene_root = Node3D.new()
	add_child(scene_root)

	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.12, 0.13, 0.16) if bright else Color(0.05, 0.05, 0.07)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.85, 0.8)
	env.ambient_light_energy = 0.8 if bright else 0.35
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.ssao_enabled = not bright
	env.glow_enabled = not bright
	var we := WorldEnvironment.new()
	we.environment = env
	scene_root.add_child(we)

	if bright:
		var sun := DirectionalLight3D.new()
		sun.rotation_degrees = Vector3(-60, 30, 0)
		sun.shadow_enabled = true
		scene_root.add_child(sun)
	return scene_root


func _spawn_player(parent: Node3D, pos: Vector3) -> void:
	var player := PlayerScript.new()
	player.position = pos
	player.menu_requested.connect(_on_player_menu)
	parent.add_child(player)
	player.camera.current = true


func _on_player_menu() -> void:
	if return_to_creator:
		start_creator(last_data)
	else:
		show_menu()


# ------------------------------------------------------------------ modos

func start_tutorial() -> void:
	return_to_creator = false
	var c := _new_container(false)
	c.add_child(RoomBuilder.build_prefab_room())
	_spawn_player(c, Vector3(0, 0.1, 2.0)) # mirando hacia la puerta (norte, -Z)


func start_play(room: Dictionary, from_creator: bool) -> void:
	return_to_creator = from_creator
	last_data = room
	var c := _new_container(false)
	c.add_child(Shell.build(true))
	for o in room["objects"]:
		if not Catalog.TYPES.has(o["type"]):
			continue
		var n := Catalog.make_object(o["type"], o["props"], float(o["rot"]), true)
		n.position = Vector3(float(o["x"]), float(o["y"]), float(o["z"]))
		c.add_child(n)
	_spawn_player(c, Shell.SPAWN)


func start_creator(room: Dictionary) -> void:
	return_to_creator = false
	last_data = room
	var c := _new_container(true)
	var creator := Creator.new()
	creator.data = room
	creator.exit_requested.connect(show_menu)
	creator.test_requested.connect(func(d): start_play(d, true))
	creator.publish_requested.connect(_on_publish.bind(creator))
	c.add_child(creator)


func _play_saved(room_name: String) -> void:
	var d := RoomData.load_room(room_name)
	if not d.is_empty():
		start_play(d, false)


func _edit_saved(room_name: String) -> void:
	var d := RoomData.load_room(room_name)
	if not d.is_empty():
		start_creator(d)


# ------------------------------------------------------------------ menú

## Publica la sala del editor en el servidor.
func _on_publish(room: Dictionary, author: String, creator) -> void:
	if not online.is_configured():
		creator.show_message("Falta configurar el servidor: edita online_config.gd (mira el README).")
		return
	creator.show_message("Publicando sala...")
	var r: Dictionary = await online.publish_room(room, author)
	if not is_instance_valid(creator):
		return
	if r["ok"]:
		creator.show_message("¡Sala publicada! Ya aparece en «Salas de la comunidad».")
	else:
		creator.show_message("No se pudo publicar: " + str(r["error"]))


## Pantalla con las salas que han publicado otros jugadores.
func show_community() -> void:
	_clear()
	return_to_creator = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Salas de la comunidad"
	title.add_theme_font_size_override("font_size", 32)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(status)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(640, 320)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var buttons := HBoxContainer.new()
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(buttons)
	var refresh := Button.new()
	refresh.text = "Actualizar"
	refresh.pressed.connect(_load_community.bind(list, status))
	buttons.add_child(refresh)
	var back := Button.new()
	back.text = "Volver al menú"
	back.pressed.connect(show_menu)
	buttons.add_child(back)

	_load_community(list, status)


func _load_community(list: VBoxContainer, status: Label) -> void:
	if not online.is_configured():
		status.text = "El servidor todavía no está configurado (mira el README)."
		return
	status.text = "Cargando salas..."
	for c in list.get_children():
		c.queue_free()
	var r: Dictionary = await online.list_rooms()
	if not is_instance_valid(list):
		return
	if not r["ok"]:
		status.text = "No se pudo cargar: " + str(r["error"])
		return
	var rows: Array = r["data"]
	status.text = "" if rows.size() > 0 else "Todavía no hay salas publicadas. ¡Publica la primera!"
	for item in rows:
		if typeof(item) != TYPE_DICTIONARY:
			continue
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = "%s — por %s" % [str(item.get("name", "?")), str(item.get("author", "?"))]
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.clip_text = true
		row.add_child(l)
		var id := str(item.get("id", ""))
		var play_b := Button.new()
		play_b.text = "Jugar"
		play_b.pressed.connect(_play_online.bind(id, status))
		row.add_child(play_b)
		var copy_b := Button.new()
		copy_b.text = "Guardar copia"
		copy_b.pressed.connect(_copy_online.bind(id, status))
		row.add_child(copy_b)
		list.add_child(row)


func _play_online(id: String, status: Label) -> void:
	status.text = "Descargando sala..."
	var r: Dictionary = await online.download_room(id)
	if not is_instance_valid(status):
		return
	if not r["ok"]:
		status.text = "No se pudo descargar: " + str(r["error"])
		return
	start_play(r["data"], false)


func _copy_online(id: String, status: Label) -> void:
	status.text = "Descargando sala..."
	var r: Dictionary = await online.download_room(id)
	if not is_instance_valid(status):
		return
	if not r["ok"]:
		status.text = "No se pudo descargar: " + str(r["error"])
		return
	var d: Dictionary = r["data"]
	d["name"] = RoomData.unique_name(str(d["name"]))
	if RoomData.save_room(d) != "":
		status.text = "Guardada en «Mis salas» como: " + str(d["name"])
	else:
		status.text = "No se pudo guardar la sala."


func _menu_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(380, 46)
	b.pressed.connect(cb)
	return b


func show_menu() -> void:
	_clear()
	return_to_creator = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	menu_layer = CanvasLayer.new()
	add_child(menu_layer)

	var bg := ColorRect.new()
	bg.color = Color(0.08, 0.09, 0.12)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(bg)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	menu_layer.add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	center.add_child(box)

	var title := Label.new()
	title.text = "Escape Room Maker"
	title.add_theme_font_size_override("font_size", 40)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	box.add_child(_menu_button("Tutorial (sala de práctica)", start_tutorial))
	box.add_child(_menu_button("Crear una sala nueva", func(): start_creator(RoomData.new_room())))
	box.add_child(_menu_button("Salas de la comunidad", show_community))

	var sub := Label.new()
	sub.text = "Mis salas guardadas"
	sub.add_theme_font_size_override("font_size", 20)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(380, 200)
	box.add_child(scroll)
	var list := VBoxContainer.new()
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(list)

	var rooms := RoomData.list_rooms()
	if rooms.is_empty():
		var empty := Label.new()
		empty.text = "(todavía no has guardado ninguna sala)"
		empty.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		list.add_child(empty)
	for n in rooms:
		var row := HBoxContainer.new()
		var nl := Label.new()
		nl.text = n
		nl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(nl)
		var play_b := Button.new()
		play_b.text = "Jugar"
		play_b.pressed.connect(_play_saved.bind(n))
		row.add_child(play_b)
		var edit_b := Button.new()
		edit_b.text = "Editar"
		edit_b.pressed.connect(_edit_saved.bind(n))
		row.add_child(edit_b)
		list.add_child(row)
