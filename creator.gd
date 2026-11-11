extends Node3D
## Modo creador: cámara libre, colocar / mover / girar / borrar objetos y editar sus propiedades.

const Catalog = preload("res://catalog.gd")
const RoomData = preload("res://room_data.gd")
const Shell = preload("res://shell.gd")

signal exit_requested
signal test_requested(room)
signal publish_requested(room, author)

const HINT := "Clic izq: colocar o seleccionar (arrastra para mover) · Mantén clic der + WASD: volar (Q/E: bajar/subir) · Rueda: acercar · R: girar · Supr: borrar · Esc: soltar herramienta"

var data: Dictionary = {}
var nodes := {}          # id -> Node3D
var next_id := 1
var current_tool := "select"
var selected_id := -1
var ghost: Node3D = null
var ghost_rot := 0
var drag_pending := false
var dragging := false
var press_pos := Vector2.ZERO
var warned := false

var cam: Camera3D
var yaw := 0.0
var pitch := deg_to_rad(-45.0)
var looking := false
var highlight: MeshInstance3D = null

var top_bar: PanelContainer
var left_panel: PanelContainer
var props_panel: PanelContainer
var props_box: VBoxContainer
var name_edit: LineEdit
var author_edit: LineEdit
var status_label: Label
var tool_buttons := {}


func _ready() -> void:
	add_child(Shell.build(false))
	cam = Camera3D.new()
	cam.position = Vector3(0, 7.0, 8.0)
	add_child(cam)
	cam.current = true
	_apply_camera()
	_build_ui()
	for o in data["objects"]:
		next_id = maxi(next_id, int(o["id"]) + 1)
		_spawn_node(o)
	name_edit.text = str(data.get("name", "Mi sala"))
	_set_tool("select")
	_refresh_status()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


# ------------------------------------------------------------------ cámara

func _apply_camera() -> void:
	cam.rotation = Vector3(pitch, yaw, 0.0)


func _process(delta: float) -> void:
	if looking and not Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT):
		looking = false
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_fly(delta)
	_update_ghost()
	_update_drag()


func _fly(delta: float) -> void:
	if not looking:
		return
	var b := cam.global_transform.basis
	var dir := Vector3.ZERO
	if Input.is_key_pressed(KEY_W):
		dir -= b.z
	if Input.is_key_pressed(KEY_S):
		dir += b.z
	if Input.is_key_pressed(KEY_A):
		dir -= b.x
	if Input.is_key_pressed(KEY_D):
		dir += b.x
	if Input.is_key_pressed(KEY_E):
		dir += Vector3.UP
	if Input.is_key_pressed(KEY_Q):
		dir -= Vector3.UP
	if dir != Vector3.ZERO:
		var speed := 7.0 * (2.5 if Input.is_key_pressed(KEY_SHIFT) else 1.0)
		cam.global_position += dir.normalized() * speed * delta


# ------------------------------------------------------------------ entrada

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		match mb.button_index:
			MOUSE_BUTTON_RIGHT:
				looking = mb.pressed
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED if mb.pressed else Input.MOUSE_MODE_VISIBLE
			MOUSE_BUTTON_LEFT:
				if mb.pressed:
					_on_left_press()
			MOUSE_BUTTON_WHEEL_UP:
				if mb.pressed:
					cam.global_position += -cam.global_transform.basis.z * 0.8
			MOUSE_BUTTON_WHEEL_DOWN:
				if mb.pressed:
					cam.global_position += cam.global_transform.basis.z * 0.8
	elif event is InputEventMouseMotion and looking:
		var mm := event as InputEventMouseMotion
		yaw -= mm.relative.x * 0.003
		pitch = clampf(pitch - mm.relative.y * 0.003, -1.5, 1.5)
		_apply_camera()
	elif event is InputEventKey:
		var ke := event as InputEventKey
		if not ke.pressed or ke.echo:
			return
		match ke.keycode:
			KEY_R:
				_rotate_current()
			KEY_DELETE, KEY_BACKSPACE, KEY_X:
				_delete_selected()
			KEY_ESCAPE:
				if current_tool != "select":
					_set_tool("select")
				else:
					_select(-1)


func _on_left_press() -> void:
	get_viewport().gui_release_focus()
	if current_tool == "select":
		var hit := _mouse_ray(3)
		var id := -1
		if hit.size() > 0:
			id = _id_from_collider(hit["collider"])
		_select(id)
		if id != -1 and not _is_fixed(id):
			drag_pending = true
			press_pos = get_viewport().get_mouse_position()
	else:
		_place_current()


# ------------------------------------------------------------------ rayos y colocación

func _mouse_ray(mask: int) -> Dictionary:
	var mp := get_viewport().get_mouse_position()
	var from := cam.project_ray_origin(mp)
	var to := from + cam.project_ray_normal(mp) * 200.0
	var q := PhysicsRayQueryParameters3D.create(from, to, mask)
	return get_world_3d().direct_space_state.intersect_ray(q)


## Punto donde caería un objeto bajo el cursor (suelo o la parte de arriba de otro objeto).
func _placement_point(info: Dictionary):
	var hit := _mouse_ray(1)
	var p := Vector3.ZERO
	if hit.size() > 0 and hit["normal"].y > 0.7:
		p = hit["position"]
	else:
		var mp := get_viewport().get_mouse_position()
		var from := cam.project_ray_origin(mp)
		var dir := cam.project_ray_normal(mp)
		if absf(dir.y) < 0.001:
			return null
		var t := -from.y / dir.y
		if t < 0.0:
			return null
		p = from + dir * t
	var snap: float = info["snap"]
	var lim := Shell.HALF - 0.3
	p.x = clampf(snappedf(p.x, snap), -lim, lim)
	p.z = clampf(snappedf(p.z, snap), -lim, lim)
	return p


func _over_ui(mp: Vector2) -> bool:
	for p in [top_bar, left_panel, props_panel]:
		if p.visible and p.get_global_rect().has_point(mp):
			return true
	return false


func _update_ghost() -> void:
	if ghost == null:
		return
	var mp := get_viewport().get_mouse_position()
	if looking or _over_ui(mp):
		ghost.visible = false
		return
	var p = _placement_point(Catalog.TYPES[current_tool])
	if p == null:
		ghost.visible = false
		return
	ghost.visible = true
	ghost.position = p
	ghost.rotation.y = deg_to_rad(ghost_rot)


func _place_current() -> void:
	if ghost == null or not ghost.visible:
		return
	var id := next_id
	next_id += 1
	var o := {
		"id": id, "type": current_tool,
		"x": ghost.position.x, "y": ghost.position.y, "z": ghost.position.z,
		"rot": ghost_rot, "props": Catalog.default_props(current_tool),
	}
	data["objects"].append(o)
	_spawn_node(o)
	_modified()


# ------------------------------------------------------------------ arrastrar

func _update_drag() -> void:
	var lmb := Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	if (drag_pending or dragging) and not lmb:
		_finish_drag()
		return
	if drag_pending and not dragging:
		if get_viewport().get_mouse_position().distance_to(press_pos) > 6.0:
			dragging = true
			_set_body_layer(selected_id, 0) # que el rayo no choque con el propio objeto
	if dragging and nodes.has(selected_id):
		var o := _find(selected_id)
		var p = _placement_point(Catalog.TYPES[o["type"]])
		if p != null:
			nodes[selected_id].position = p


func _finish_drag() -> void:
	if dragging and nodes.has(selected_id):
		var o := _find(selected_id)
		var n: Node3D = nodes[selected_id]
		o["x"] = n.position.x
		o["y"] = n.position.y
		o["z"] = n.position.z
		_restore_layer(selected_id)
		_modified()
	dragging = false
	drag_pending = false


func _set_body_layer(id: int, layer: int) -> void:
	if not nodes.has(id):
		return
	var n: Node3D = nodes[id]
	var b := n.get_node_or_null("Body") as StaticBody3D
	if b != null:
		b.collision_layer = layer


func _restore_layer(id: int) -> void:
	var o := _find(id)
	if o.is_empty():
		return
	var solid: bool = Catalog.TYPES[o["type"]]["solid"]
	_set_body_layer(id, 1 if solid else 2)


# ------------------------------------------------------------------ objetos

func _find(id: int) -> Dictionary:
	for o in data["objects"]:
		if int(o["id"]) == id:
			return o
	return {}


func _is_fixed(id: int) -> bool:
	var o := _find(id)
	if o.is_empty():
		return false
	return bool(Catalog.TYPES[o["type"]].get("fixed", false))


func _id_from_collider(c) -> int:
	if c != null and c.has_meta("oid"):
		return int(c.get_meta("oid"))
	return -1


func _spawn_node(o: Dictionary) -> void:
	if not Catalog.TYPES.has(o["type"]):
		return
	var id := int(o["id"])
	if nodes.has(id) and is_instance_valid(nodes[id]):
		nodes[id].queue_free()
	var n := Catalog.make_object(o["type"], o["props"], float(o["rot"]), false)
	n.position = Vector3(float(o["x"]), float(o["y"]), float(o["z"]))
	add_child(n)
	var body := n.get_node_or_null("Body")
	if body != null:
		body.set_meta("oid", id)
	nodes[id] = n


func _rotate_current() -> void:
	if ghost != null:
		ghost_rot = (ghost_rot + 90) % 360
	elif selected_id != -1 and not _is_fixed(selected_id):
		var o := _find(selected_id)
		o["rot"] = (int(o["rot"]) + 90) % 360
		nodes[selected_id].rotation.y = deg_to_rad(float(o["rot"]))
		_modified()


func _delete_selected() -> void:
	if selected_id == -1 or _is_fixed(selected_id):
		return
	var id := selected_id
	_select(-1)
	if nodes.has(id):
		nodes[id].queue_free()
		nodes.erase(id)
	var objs: Array = data["objects"]
	for i in objs.size():
		if int(objs[i]["id"]) == id:
			objs.remove_at(i)
			break
	_modified()


func _set_tool(t: String) -> void:
	current_tool = t
	if ghost != null:
		ghost.queue_free()
		ghost = null
	if t == "select":
		if tool_buttons.has("select"):
			tool_buttons["select"].button_pressed = true
		return
	_select(-1)
	ghost = Catalog.make_object(t, Catalog.default_props(t), ghost_rot, false)
	var body := ghost.get_node_or_null("Body")
	if body != null:
		ghost.remove_child(body)
		body.free()
	var mat := StandardMaterial3D.new()
	mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(0.3, 0.8, 1.0, 0.45)
	_tint(ghost, mat)
	ghost.visible = false
	add_child(ghost)


func _tint(n: Node, mat: Material) -> void:
	if n is MeshInstance3D:
		(n as MeshInstance3D).material_override = mat
	for c in n.get_children():
		_tint(c, mat)


func _select(id: int) -> void:
	selected_id = id
	if is_instance_valid(highlight):
		highlight.queue_free()
	highlight = null
	if id != -1 and nodes.has(id):
		var o := _find(id)
		var sz: Vector3 = Catalog.TYPES[o["type"]]["size"]
		highlight = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = sz + Vector3(0.05, 0.05, 0.05)
		var mat := StandardMaterial3D.new()
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.albedo_color = Color(1.0, 0.9, 0.2, 0.3)
		bm.material = mat
		highlight.mesh = bm
		highlight.position = Vector3(0, sz.y / 2.0, 0)
		nodes[id].add_child(highlight)
	_rebuild_props()


func _set_prop(key: String, value, rebuild := true) -> void:
	var o := _find(selected_id)
	if o.is_empty():
		return
	o["props"][key] = value
	_modified()
	if rebuild:
		var keep := selected_id
		_spawn_node(o)
		_select(keep)


func _modified() -> void:
	warned = false
	_refresh_status()


# ------------------------------------------------------------------ interfaz

func _place_ctrl(c: Control, al: float, at: float, ar: float, ab: float,
		ol: float, ot: float, orr: float, ob: float) -> void:
	c.anchor_left = al
	c.anchor_top = at
	c.anchor_right = ar
	c.anchor_bottom = ab
	c.offset_left = ol
	c.offset_top = ot
	c.offset_right = orr
	c.offset_bottom = ob


func _button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.pressed.connect(cb)
	return b


func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	# Barra superior
	top_bar = PanelContainer.new()
	_place_ctrl(top_bar, 0, 0, 1, 0, 0, 0, 0, 48)
	layer.add_child(top_bar)
	var hb := HBoxContainer.new()
	top_bar.add_child(hb)
	var lbl := Label.new()
	lbl.text = "Sala:"
	hb.add_child(lbl)
	name_edit = LineEdit.new()
	name_edit.custom_minimum_size = Vector2(220, 0)
	hb.add_child(name_edit)
	var author_label := Label.new()
	author_label.text = "Autor:"
	hb.add_child(author_label)
	author_edit = LineEdit.new()
	author_edit.custom_minimum_size = Vector2(150, 0)
	author_edit.max_length = 30
	author_edit.placeholder_text = "Anónimo"
	author_edit.text = RoomData.load_author()
	hb.add_child(author_edit)
	hb.add_child(_button("Guardar", _on_save))
	hb.add_child(_button("Probar sala", _on_test))
	hb.add_child(_button("Publicar", _on_publish))
	hb.add_child(_button("Menú", _on_exit))

	# Panel izquierdo: herramientas
	left_panel = PanelContainer.new()
	_place_ctrl(left_panel, 0, 0, 0, 1, 0, 52, 170, 0)
	layer.add_child(left_panel)
	var lv := VBoxContainer.new()
	left_panel.add_child(lv)
	var title := Label.new()
	title.text = "Objetos"
	title.add_theme_font_size_override("font_size", 18)
	lv.add_child(title)
	var group := ButtonGroup.new()
	var sel := Button.new()
	sel.text = "Seleccionar / mover"
	sel.toggle_mode = true
	sel.button_group = group
	sel.pressed.connect(_set_tool.bind("select"))
	lv.add_child(sel)
	tool_buttons["select"] = sel
	lv.add_child(HSeparator.new())
	for t in Catalog.PLACEABLE:
		var b := Button.new()
		b.text = Catalog.TYPES[t]["name"]
		b.toggle_mode = true
		b.button_group = group
		b.pressed.connect(_set_tool.bind(t))
		lv.add_child(b)
		tool_buttons[t] = b

	# Panel derecho: propiedades del objeto seleccionado
	props_panel = PanelContainer.new()
	props_panel.custom_minimum_size = Vector2(290, 0)
	_place_ctrl(props_panel, 1, 0, 1, 0, -290, 52, 0, 52)
	layer.add_child(props_panel)
	props_box = VBoxContainer.new()
	props_panel.add_child(props_box)
	props_panel.visible = false

	# Línea de estado
	status_label = Label.new()
	status_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	status_label.add_theme_color_override("font_outline_color", Color.BLACK)
	status_label.add_theme_constant_override("outline_size", 6)
	_place_ctrl(status_label, 0, 1, 1, 1, 180, -52, -300, -8)
	layer.add_child(status_label)


func _status(text: String) -> void:
	status_label.text = text


func _refresh_status() -> void:
	var w := RoomData.validate(data)
	if w.is_empty():
		_status(HINT)
	else:
		_status("Aviso: " + w[0])


func _rebuild_props() -> void:
	for c in props_box.get_children():
		props_box.remove_child(c)
		c.queue_free()
	props_panel.visible = selected_id != -1
	if selected_id == -1:
		return
	var o := _find(selected_id)
	var type: String = o["type"]
	var props: Dictionary = o["props"]

	var title := Label.new()
	title.text = Catalog.TYPES[type]["name"]
	title.add_theme_font_size_override("font_size", 18)
	props_box.add_child(title)

	match type:
		"llave":
			_add_option("Color de la llave", Catalog.KEY_COLORS, str(props.get("color", "Dorada")), "",
				func(v): _set_prop("color", v))
		"cofre":
			var chest_opts: Array = [""] + Catalog.KEY_COLORS
			_add_option("Se abre con", chest_opts, str(props.get("needs", "")), "Sin llave",
				func(v): _set_prop("needs", v))
			_add_option("Contiene", chest_opts, str(props.get("gives", "")), "Nada",
				func(v): _set_prop("gives", v))
		"puerta_salida":
			var door_opts: Array = [""] + Catalog.KEY_COLORS
			_add_option("La puerta se abre con", door_opts, str(props.get("needs", "")), "Sin llave",
				func(v): _set_prop("needs", v))
		"nota":
			var l := Label.new()
			l.text = "Texto de la nota"
			props_box.add_child(l)
			var le := LineEdit.new()
			le.max_length = 160
			le.text = str(props.get("text", ""))
			le.custom_minimum_size = Vector2(260, 0)
			le.text_changed.connect(func(t): _set_prop("text", t, false))
			props_box.add_child(le)

	if not _is_fixed(selected_id):
		props_box.add_child(HSeparator.new())
		props_box.add_child(_button("Girar 90° (R)", _rotate_current))
		props_box.add_child(_button("Borrar (Supr)", _delete_selected))


func _add_option(title: String, values: Array, current: String, empty_label: String,
		on_change: Callable) -> void:
	var l := Label.new()
	l.text = title
	props_box.add_child(l)
	var ob := OptionButton.new()
	for v in values:
		ob.add_item(empty_label if str(v) == "" else str(v))
	ob.select(maxi(values.find(current), 0))
	ob.item_selected.connect(func(i: int): on_change.call(values[i]))
	props_box.add_child(ob)


# ------------------------------------------------------------------ barra superior

func _save(silent := false) -> void:
	var n := name_edit.text.strip_edges()
	if n == "":
		n = "Mi sala"
	data["name"] = n
	var path := RoomData.save_room(data)
	if path == "":
		_status("No se pudo guardar la sala.")
	elif not silent:
		_status("Sala guardada: " + n)


func _on_save() -> void:
	_save()


func _on_test() -> void:
	_save(true)
	var w := RoomData.validate(data)
	if not w.is_empty() and not warned:
		warned = true
		_status("Aviso: " + w[0] + " — Pulsa «Probar sala» otra vez para jugarla de todos modos.")
		return
	test_requested.emit(data)


func _on_exit() -> void:
	_save(true)
	exit_requested.emit()


func _on_publish() -> void:
	_save(true)
	if data["objects"].size() < 2:
		_status("Agrega al menos un objeto antes de publicar la sala.")
		return
	var w := RoomData.validate(data)
	if not w.is_empty():
		_status("Arregla esto antes de publicar: " + w[0])
		return
	var author := author_edit.text.strip_edges()
	if author == "":
		author = "Anónimo"
	RoomData.save_author(author)
	publish_requested.emit(data, author)


## Muestra un mensaje en la línea de estado (lo usa main.gd).
func show_message(text: String) -> void:
	_status(text)
