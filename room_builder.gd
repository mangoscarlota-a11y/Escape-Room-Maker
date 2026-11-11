extends RefCounted
## Construye salas con piezas simples (cajas) generadas por código.
## Más adelante el modo creador usará estas mismas piezas para armar salas guardadas.

const Interactable = preload("res://interactable.gd")


## Crea una caja con malla y colisión. Si `interactive` es true, el jugador puede usarla con E.
static func box(parent: Node, size: Vector3, pos: Vector3, color: Color,
		roughness := 0.85, solid := true, interactive := false) -> StaticBody3D:
	var body: StaticBody3D = Interactable.new() if interactive else StaticBody3D.new()
	body.position = pos

	var mesh := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = roughness
	bm.material = mat
	mesh.mesh = bm
	body.add_child(mesh)

	if solid or interactive:
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = size
		cs.shape = bs
		body.add_child(cs)

	parent.add_child(body)
	return body


static func build_prefab_room() -> Node3D:
	var room := Node3D.new()
	room.name = "SalaPrefabricada"

	var wall := Color(0.86, 0.82, 0.74)
	var wood := Color(0.42, 0.28, 0.17)
	var dark_wood := Color(0.28, 0.18, 0.11)

	# --- Suelo y techo (la sala mide 6x6 m por dentro, 3 m de alto) ---
	box(room, Vector3(6.4, 0.2, 6.4), Vector3(0, -0.1, 0), Color(0.5, 0.34, 0.2), 0.6)
	box(room, Vector3(6.4, 0.2, 6.4), Vector3(0, 3.1, 0), Color(0.93, 0.91, 0.87))

	# --- Paredes ---
	box(room, Vector3(0.2, 3.0, 6.4), Vector3(-3.1, 1.5, 0), wall)  # oeste
	box(room, Vector3(0.2, 3.0, 6.4), Vector3(3.1, 1.5, 0), wall)   # este
	box(room, Vector3(6.4, 3.0, 0.2), Vector3(0, 1.5, 3.1), wall)   # sur
	# norte, con hueco para la puerta
	box(room, Vector3(2.6, 3.0, 0.2), Vector3(-1.9, 1.5, -3.1), wall)
	box(room, Vector3(2.6, 3.0, 0.2), Vector3(1.9, 1.5, -3.1), wall)
	box(room, Vector3(1.2, 0.9, 0.2), Vector3(0, 2.55, -3.1), wall)

	# --- Zócalos (solo decoración) ---
	var base := Color(0.95, 0.94, 0.9)
	box(room, Vector3(6.0, 0.12, 0.04), Vector3(0, 0.06, 2.98), base, 0.7, false)
	box(room, Vector3(0.04, 0.12, 6.0), Vector3(-2.98, 0.06, 0), base, 0.7, false)
	box(room, Vector3(0.04, 0.12, 6.0), Vector3(2.98, 0.06, 0), base, 0.7, false)
	box(room, Vector3(2.4, 0.12, 0.04), Vector3(-1.8, 0.06, -2.98), base, 0.7, false)
	box(room, Vector3(2.4, 0.12, 0.04), Vector3(1.8, 0.06, -2.98), base, 0.7, false)

	# --- Puerta (cerrada con llave) ---
	var door_state := {"open": false}
	var door := box(room, Vector3(1.2, 2.1, 0.1), Vector3(0, 1.05, -3.1), dark_wood, 0.6, true, true)
	door.set("prompt_text", "Abrir puerta")
	var on_door = func(by):
		if door_state["open"]:
			return
		if by.has_item("Llave de la puerta"):
			by.remove_item("Llave de la puerta")
			door_state["open"] = true
			door.set("prompt_text", "Puerta abierta")
			by.show_message("¡Abriste la puerta! Lograste escapar. Pulsa M para volver al menú.", 6.0)
			# La puerta se desliza hacia dentro de la pared.
			door.create_tween().tween_property(door, "position:x", 1.25, 1.0)
		else:
			by.show_message("La puerta está cerrada con llave. Necesitas la llave de la puerta.")
	door.connect("interacted", on_door)

	# --- Alfombra ---
	box(room, Vector3(2.6, 0.02, 1.8), Vector3(0, 0.011, -0.2), Color(0.45, 0.12, 0.14), 1.0, false)

	# --- Mesa ---
	var table_pos := Vector3(0, 0, -0.5)
	box(room, Vector3(1.4, 0.08, 0.8), table_pos + Vector3(0, 0.76, 0), wood, 0.5)
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			box(room, Vector3(0.08, 0.72, 0.08),
				table_pos + Vector3(0.62 * sx, 0.36, 0.32 * sz), dark_wood, 0.5)

	# --- Lámpara de mesa (se enciende y apaga con E) ---
	var lamp := box(room, Vector3(0.2, 0.35, 0.2), table_pos + Vector3(0.45, 0.975, 0),
		Color(0.95, 0.85, 0.55), 0.4, true, true)
	lamp.set("prompt_text", "Encender / apagar lámpara")
	var lamp_light := OmniLight3D.new()
	lamp_light.position = Vector3(0, 0.25, 0)
	lamp_light.light_color = Color(1.0, 0.82, 0.55)
	lamp_light.light_energy = 1.2
	lamp_light.omni_range = 3.5
	lamp.add_child(lamp_light)
	lamp.connect("interacted", func(_by): lamp_light.visible = not lamp_light.visible)

	# --- Cofre ---
	var chest_state := {"open": false}
	var chest := box(room, Vector3(0.8, 0.45, 0.5), Vector3(2.2, 0.225, -2.5), wood, 0.55, true, true)
	chest.set("prompt_text", "Abrir cofre")
	# La tapa gira alrededor de una bisagra en el borde trasero del cofre.
	var hinge := Node3D.new()
	hinge.position = Vector3(2.2, 0.45, -2.75)
	room.add_child(hinge)
	box(hinge, Vector3(0.82, 0.06, 0.52), Vector3(0, 0.03, 0.26), dark_wood, 0.5, false)
	var on_chest = func(by):
		if chest_state["open"]:
			by.show_message("El cofre ya está vacío.")
			return
		if by.has_item("Llave del cofre"):
			by.remove_item("Llave del cofre")
			chest_state["open"] = true
			chest.set("prompt_text", "Cofre abierto")
			hinge.create_tween().tween_property(hinge, "rotation:x", deg_to_rad(-110.0), 0.8)
			by.add_item("Llave de la puerta")
			by.show_message("Dentro había otra llave: Llave de la puerta.")
		else:
			by.show_message("El cofre está cerrado con llave.")
	chest.connect("interacted", on_chest)

	# --- Librero contra la pared oeste ---
	_build_bookshelf(room, Vector3(-2.8, 0, 1.0), dark_wood)

	# --- Llave del cofre: sobre la tabla más alta del librero ---
	_make_key(room, Vector3(-2.8, 2.04, 0.4), "Llave del cofre")

	# --- Nota con la pista, sobre la mesa ---
	var note := box(room, Vector3(0.3, 0.01, 0.2), table_pos + Vector3(-0.4, 0.805, 0.0),
		Color(0.96, 0.94, 0.86), 0.95, true, true)
	note.set("prompt_text", "Leer nota")
	note.connect("interacted", func(by): by.show_message("La llave del cofre está en lo más alto del librero.", 4.0))

	# --- Cuadro en la pared este ---
	box(room, Vector3(0.05, 0.8, 1.2), Vector3(2.97, 1.7, 0), dark_wood, 0.5, false)
	box(room, Vector3(0.02, 0.7, 1.1), Vector3(2.94, 1.7, 0), Color(0.25, 0.5, 0.55), 0.9, false)

	# --- Luz del techo ---
	box(room, Vector3(0.35, 0.05, 0.35), Vector3(0, 2.98, 0), Color(1, 0.97, 0.9), 0.3, false)
	var ceiling_light := OmniLight3D.new()
	ceiling_light.position = Vector3(0, 2.7, 0)
	ceiling_light.light_color = Color(1.0, 0.95, 0.85)
	ceiling_light.light_energy = 1.0
	ceiling_light.omni_range = 8.0
	ceiling_light.shadow_enabled = true
	room.add_child(ceiling_light)

	return room


## Llave que se recoge con E y pasa al inventario del jugador.
static func _make_key(room: Node3D, pos: Vector3, item_name: String) -> void:
	var key := box(room, Vector3(0.16, 0.04, 0.07), pos, Color(0.85, 0.65, 0.15), 0.3, false, true)
	key.set("prompt_text", "Recoger " + item_name)
	key.connect("interacted", func(by):
		by.add_item(item_name)
		by.show_message("Conseguiste: " + item_name)
		key.queue_free())


static func _build_bookshelf(room: Node3D, pos: Vector3, color: Color) -> void:
	# Estructura: panel trasero, dos laterales y cinco tablas.
	box(room, Vector3(0.03, 2.0, 1.6), pos + Vector3(-0.17, 1.0, 0), color, 0.6)
	box(room, Vector3(0.35, 2.0, 0.05), pos + Vector3(0, 1.0, -0.775), color, 0.6)
	box(room, Vector3(0.35, 2.0, 0.05), pos + Vector3(0, 1.0, 0.775), color, 0.6)
	var levels := [0.1, 0.6, 1.1, 1.6, 2.0]
	for y in levels:
		box(room, Vector3(0.35, 0.04, 1.6), pos + Vector3(0, y, 0), color, 0.6)

	# Libros de colores (decoración, sin colisión)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var palette := [
		Color(0.55, 0.15, 0.15), Color(0.15, 0.3, 0.5), Color(0.2, 0.45, 0.25),
		Color(0.7, 0.55, 0.2), Color(0.35, 0.2, 0.4), Color(0.8, 0.75, 0.65),
	]
	for i in range(4):
		var z := -0.7
		while z < 0.7:
			var w := rng.randf_range(0.04, 0.08)
			var h := rng.randf_range(0.22, 0.36)
			if rng.randf() < 0.85:
				box(room, Vector3(0.22, h, w),
					pos + Vector3(0, levels[i] + 0.02 + h / 2.0, z + w / 2.0),
					palette[rng.randi() % palette.size()], 0.8, false)
			z += w + 0.005
