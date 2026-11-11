extends RefCounted
## Catálogo de objetos que se pueden colocar en una sala.
## Cada objeto se dibuja con piezas simples (cajas) y, en modo juego, recibe su lógica.

const Interactable = preload("res://interactable.gd")

const KEY_COLORS := ["Roja", "Azul", "Verde", "Dorada"]
const COLOR_VALUES := {
	"Roja": Color(0.8, 0.15, 0.15),
	"Azul": Color(0.2, 0.4, 0.85),
	"Verde": Color(0.2, 0.65, 0.3),
	"Dorada": Color(0.9, 0.7, 0.15),
}
const GREY := Color(0.45, 0.45, 0.48)

# size = tamaño aproximado (también la colisión); pick = colisión más grande para objetos pequeños;
# snap = rejilla al colocar; solid = bloquea al jugador; fixed = no se puede borrar ni mover.
const TYPES := {
	"mesa": {"name": "Mesa", "size": Vector3(1.4, 0.8, 0.8), "snap": 0.25, "solid": true},
	"silla": {"name": "Silla", "size": Vector3(0.5, 0.95, 0.5), "snap": 0.25, "solid": true},
	"librero": {"name": "Librero", "size": Vector3(1.6, 2.0, 0.35), "snap": 0.25, "solid": true},
	"caja": {"name": "Caja", "size": Vector3(0.6, 0.6, 0.6), "snap": 0.25, "solid": true},
	"alfombra": {"name": "Alfombra", "size": Vector3(2.0, 0.02, 1.4), "snap": 0.25, "solid": false},
	"lampara": {"name": "Lámpara", "size": Vector3(0.22, 0.45, 0.22), "snap": 0.05, "solid": false},
	"cofre": {"name": "Cofre", "size": Vector3(0.8, 0.51, 0.5), "snap": 0.25, "solid": true},
	"llave": {"name": "Llave", "size": Vector3(0.28, 0.05, 0.07), "pick": Vector3(0.32, 0.12, 0.2), "snap": 0.05, "solid": false},
	"nota": {"name": "Nota", "size": Vector3(0.3, 0.02, 0.2), "pick": Vector3(0.34, 0.1, 0.24), "snap": 0.05, "solid": false},
	"puerta_salida": {"name": "Puerta de salida", "size": Vector3(1.2, 2.1, 0.1), "snap": 0.25, "solid": true, "fixed": true},
}
const PLACEABLE := ["mesa", "silla", "librero", "caja", "alfombra", "lampara", "cofre", "llave", "nota"]
const INTERACTIVE := ["llave", "nota", "lampara", "cofre", "puerta_salida"]


static func default_props(type: String) -> Dictionary:
	match type:
		"llave":
			return {"color": "Dorada"}
		"cofre":
			return {"needs": "", "gives": ""}
		"puerta_salida":
			return {"needs": "Dorada"}
		"nota":
			return {"text": "Escribe aquí tu pista..."}
	return {}


## Crea un objeto. En modo creador (play = false) solo tiene colisión para poder seleccionarlo.
## En modo juego (play = true) los objetos interactivos reciben su lógica.
static func make_object(type: String, props: Dictionary, rot_deg: float, play: bool) -> Node3D:
	if not TYPES.has(type):
		return Node3D.new()
	var info: Dictionary = TYPES[type]
	var root := Node3D.new()
	root.name = type
	root.rotation.y = deg_to_rad(rot_deg)

	var visual := Node3D.new()
	visual.name = "Visual"
	root.add_child(visual)
	_build_visual(visual, type, props, play)

	var interactive: bool = INTERACTIVE.has(type)
	var solid: bool = info["solid"]
	if play and not solid and not interactive:
		return root # decoración sin colisión (alfombra)

	var body: StaticBody3D
	if play and interactive:
		body = Interactable.new()
	else:
		body = StaticBody3D.new()
	body.name = "Body"
	body.collision_layer = 1 if solid else 2
	var csize: Vector3 = info.get("pick", info["size"])
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = csize
	cs.shape = bs
	cs.position = Vector3(0, csize.y / 2.0, 0)
	body.add_child(cs)
	root.add_child(body)

	if play and interactive:
		_attach_logic(root, body, type, props)
	return root


static func _part(parent: Node3D, size: Vector3, pos: Vector3, color: Color,
		rough := 0.8, glow := false) -> MeshInstance3D:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = rough
	if glow:
		mat.emission_enabled = true
		mat.emission = color
		mat.emission_energy_multiplier = 0.8
	bm.material = mat
	m.mesh = bm
	m.position = pos
	parent.add_child(m)
	return m


static func _build_visual(v: Node3D, type: String, props: Dictionary, play: bool) -> void:
	var wood := Color(0.42, 0.28, 0.17)
	var dark := Color(0.28, 0.18, 0.11)
	match type:
		"mesa":
			_part(v, Vector3(1.4, 0.08, 0.8), Vector3(0, 0.76, 0), wood, 0.5)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_part(v, Vector3(0.08, 0.72, 0.08), Vector3(0.62 * sx, 0.36, 0.32 * sz), dark, 0.5)
		"silla":
			_part(v, Vector3(0.45, 0.06, 0.45), Vector3(0, 0.45, 0), wood, 0.6)
			_part(v, Vector3(0.45, 0.5, 0.05), Vector3(0, 0.7, -0.2), wood, 0.6)
			for sx in [-1, 1]:
				for sz in [-1, 1]:
					_part(v, Vector3(0.05, 0.42, 0.05), Vector3(0.19 * sx, 0.21, 0.19 * sz), dark, 0.6)
		"librero":
			_part(v, Vector3(1.6, 2.0, 0.03), Vector3(0, 1.0, -0.16), dark, 0.6)
			_part(v, Vector3(0.05, 2.0, 0.35), Vector3(-0.775, 1.0, 0), dark, 0.6)
			_part(v, Vector3(0.05, 2.0, 0.35), Vector3(0.775, 1.0, 0), dark, 0.6)
			var levels := [0.1, 0.6, 1.1, 1.6, 1.98]
			for lv in levels:
				_part(v, Vector3(1.6, 0.04, 0.35), Vector3(0, lv, 0), dark, 0.6)
			var rng := RandomNumberGenerator.new()
			rng.seed = 7
			var palette := [
				Color(0.55, 0.15, 0.15), Color(0.15, 0.3, 0.5), Color(0.2, 0.45, 0.25),
				Color(0.7, 0.55, 0.2), Color(0.35, 0.2, 0.4), Color(0.8, 0.75, 0.65),
			]
			for i in range(4):
				var bx := -0.7
				while bx < 0.7:
					var bw := rng.randf_range(0.04, 0.08)
					var bh := rng.randf_range(0.22, 0.36)
					if rng.randf() < 0.85:
						_part(v, Vector3(bw, bh, 0.22),
							Vector3(bx + bw / 2.0, levels[i] + 0.02 + bh / 2.0, 0),
							palette[rng.randi() % palette.size()], 0.8)
					bx += bw + 0.005
		"caja":
			_part(v, Vector3(0.6, 0.6, 0.6), Vector3(0, 0.3, 0), Color(0.55, 0.4, 0.25), 0.8)
			_part(v, Vector3(0.62, 0.08, 0.62), Vector3(0, 0.3, 0), dark, 0.8)
		"alfombra":
			_part(v, Vector3(2.0, 0.02, 1.4), Vector3(0, 0.01, 0), Color(0.45, 0.12, 0.14), 1.0)
		"lampara":
			_part(v, Vector3(0.2, 0.04, 0.2), Vector3(0, 0.02, 0), dark, 0.5)
			_part(v, Vector3(0.04, 0.25, 0.04), Vector3(0, 0.165, 0), dark, 0.5)
			_part(v, Vector3(0.22, 0.18, 0.22), Vector3(0, 0.34, 0), Color(1.0, 0.85, 0.55), 0.4, true)
			if play:
				var light := OmniLight3D.new()
				light.name = "Light"
				light.position = Vector3(0, 0.3, 0)
				light.light_color = Color(1.0, 0.82, 0.55)
				light.light_energy = 1.2
				light.omni_range = 3.5
				v.add_child(light)
		"cofre":
			var chest_latch: Color = COLOR_VALUES.get(str(props.get("needs", "")), GREY)
			_part(v, Vector3(0.8, 0.45, 0.5), Vector3(0, 0.225, 0), wood, 0.55)
			# La tapa gira alrededor de una bisagra en el borde trasero.
			var hinge := Node3D.new()
			hinge.name = "Hinge"
			hinge.position = Vector3(0, 0.45, -0.25)
			v.add_child(hinge)
			_part(hinge, Vector3(0.82, 0.06, 0.52), Vector3(0, 0.03, 0.26), dark, 0.5)
			_part(v, Vector3(0.1, 0.12, 0.03), Vector3(0, 0.38, 0.26), chest_latch, 0.3)
		"llave":
			var key_color: Color = COLOR_VALUES.get(str(props.get("color", "Dorada")), GREY)
			_part(v, Vector3(0.07, 0.03, 0.07), Vector3(-0.105, 0.015, 0), key_color, 0.3)
			_part(v, Vector3(0.18, 0.02, 0.025), Vector3(0.0, 0.015, 0), key_color, 0.3)
			_part(v, Vector3(0.03, 0.02, 0.04), Vector3(0.08, 0.015, 0.03), key_color, 0.3)
		"nota":
			_part(v, Vector3(0.3, 0.01, 0.2), Vector3(0, 0.005, 0), Color(0.96, 0.94, 0.86), 0.95)
		"puerta_salida":
			var door_latch: Color = COLOR_VALUES.get(str(props.get("needs", "")), GREY)
			_part(v, Vector3(1.2, 2.1, 0.1), Vector3(0, 1.05, 0), dark, 0.6)
			_part(v, Vector3(0.12, 0.12, 0.03), Vector3(0.4, 1.0, 0.06), door_latch, 0.3)


# ---------------------------------------------------------------- lógica de juego

static func _attach_logic(root: Node3D, body: StaticBody3D, type: String, props: Dictionary) -> void:
	match type:
		"llave":
			_logic_key(root, body, props)
		"nota":
			_logic_note(body, props)
		"lampara":
			_logic_lamp(root, body)
		"cofre":
			_logic_chest(root, body, props)
		"puerta_salida":
			_logic_door(root, body, props)


static func _logic_key(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var item := "Llave " + str(props.get("color", "Dorada"))
	body.set("prompt_text", "Recoger " + item)
	var on_use = func(by):
		if not by.has_item(item):
			by.add_item(item)
		by.show_message("Conseguiste: " + item)
		root.queue_free()
	body.connect("interacted", on_use)


static func _logic_note(body: StaticBody3D, props: Dictionary) -> void:
	var note_text := str(props.get("text", ""))
	body.set("prompt_text", "Leer nota")
	var on_use = func(by):
		if note_text.strip_edges() == "":
			by.show_message("La nota está en blanco.")
		else:
			by.show_message(note_text, 7.0)
	body.connect("interacted", on_use)


static func _logic_lamp(root: Node3D, body: StaticBody3D) -> void:
	var light: OmniLight3D = root.get_node("Visual/Light")
	body.set("prompt_text", "Encender / apagar lámpara")
	var on_use = func(_by):
		light.visible = not light.visible
	body.connect("interacted", on_use)


static func _logic_chest(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var needs := str(props.get("needs", ""))
	var gives := str(props.get("gives", ""))
	var state := {"open": false}
	var hinge: Node3D = root.get_node("Visual/Hinge")
	body.set("prompt_text", "Abrir cofre")
	var on_use = func(by):
		if state["open"]:
			by.show_message("El cofre ya está abierto.")
			return
		if needs != "" and not by.has_item("Llave " + needs):
			by.show_message("El cofre está cerrado. Necesitas la Llave " + needs + ".")
			return
		state["open"] = true
		body.set("prompt_text", "Cofre abierto")
		hinge.create_tween().tween_property(hinge, "rotation:x", deg_to_rad(-110.0), 0.8)
		if gives != "":
			var reward := "Llave " + gives
			if not by.has_item(reward):
				by.add_item(reward)
			by.show_message("Dentro había: " + reward + ".")
		else:
			by.show_message("El cofre está vacío.")
	body.connect("interacted", on_use)


static func _logic_door(root: Node3D, body: StaticBody3D, props: Dictionary) -> void:
	var needs := str(props.get("needs", ""))
	var state := {"open": false}
	body.set("prompt_text", "Abrir puerta")
	var on_use = func(by):
		if state["open"]:
			return
		if needs != "" and not by.has_item("Llave " + needs):
			by.show_message("La puerta está cerrada con llave. Necesitas la Llave " + needs + ".")
			return
		state["open"] = true
		body.set("prompt_text", "Puerta abierta")
		by.show_message("¡Abriste la puerta! Lograste escapar. Pulsa M para volver al menú.", 6.0)
		# La puerta se desliza hacia dentro de la pared.
		root.create_tween().tween_property(root, "position:x", root.position.x + 1.25, 1.0)
	body.connect("interacted", on_use)
