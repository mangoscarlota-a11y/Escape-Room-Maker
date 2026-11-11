extends RefCounted
## Datos de una sala (guardar, cargar y comprobar que se puede resolver).
## Formato: {"name": String, "objects": [{"id", "type", "x", "y", "z", "rot", "props": {...}}]}

const Catalog = preload("res://catalog.gd")
const Shell = preload("res://shell.gd")

const DIR := "user://salas"
const CONFIG_PATH := "user://ajustes.cfg"
const MAX_OBJECTS := 300


static func new_room() -> Dictionary:
	return {
		"name": "Mi sala",
		"objects": [
			{"id": 0, "type": "puerta_salida", "x": 0.0, "y": 0.0, "z": -4.1, "rot": 0,
				"props": {"needs": "Dorada"}},
		],
	}


static func _path(room_name: String) -> String:
	var n := room_name.validate_filename().strip_edges()
	if n.is_empty():
		n = "sala"
	return DIR + "/" + n + ".json"


## Guarda la sala. Devuelve la ruta, o "" si falló.
static func save_room(data: Dictionary) -> String:
	DirAccess.make_dir_recursive_absolute(DIR)
	var path := _path(str(data.get("name", "sala")))
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f == null:
		return ""
	f.store_string(JSON.stringify(data, "\t"))
	f.close()
	return path


static func load_room(room_name: String) -> Dictionary:
	var path := DIR + "/" + room_name + ".json"
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d := sanitize(parsed, room_name)
	d["name"] = room_name
	return d


static func _num(v, default: float, lo: float, hi: float) -> float:
	if typeof(v) == TYPE_INT or typeof(v) == TYPE_FLOAT:
		return clampf(float(v), lo, hi)
	return default


static func _clean_color(v, allow_empty: bool, default: String) -> String:
	var c := str(v)
	if Catalog.KEY_COLORS.has(c) or (allow_empty and c == ""):
		return c
	return default


static func _clean_props(type: String, raw) -> Dictionary:
	var p := Catalog.default_props(type)
	if typeof(raw) != TYPE_DICTIONARY:
		return p
	match type:
		"llave":
			p["color"] = _clean_color(raw.get("color"), false, "Dorada")
		"cofre":
			p["needs"] = _clean_color(raw.get("needs"), true, "")
			p["gives"] = _clean_color(raw.get("gives"), true, "")
		"puerta_salida":
			p["needs"] = _clean_color(raw.get("needs"), true, "Dorada")
		"nota":
			p["text"] = str(raw.get("text", "")).substr(0, 160)
	return p


## Limpia una sala venida de un archivo o del servidor (datos no confiables):
## solo deja tipos conocidos, posiciones dentro de la sala y propiedades válidas.
static func sanitize(raw, fallback_name := "Sala") -> Dictionary:
	var lim: float = Shell.HALF - 0.3
	var room_name := fallback_name
	var door: Dictionary = new_room()["objects"][0]
	var objects: Array = []
	if typeof(raw) == TYPE_DICTIONARY:
		room_name = str(raw.get("name", fallback_name)).substr(0, 40)
		var src = raw.get("objects", [])
		if typeof(src) == TYPE_ARRAY:
			var next_id := 1
			for o in src:
				if typeof(o) != TYPE_DICTIONARY:
					continue
				var type := str(o.get("type", ""))
				if not Catalog.TYPES.has(type):
					continue
				if type == "puerta_salida":
					door["props"] = _clean_props(type, o.get("props", {}))
					continue
				if objects.size() >= MAX_OBJECTS:
					continue
				objects.append({
					"id": next_id, "type": type,
					"x": _num(o.get("x"), 0.0, -lim, lim),
					"y": _num(o.get("y"), 0.0, 0.0, 3.0),
					"z": _num(o.get("z"), 0.0, -lim, lim),
					"rot": (int(round(_num(o.get("rot"), 0.0, 0.0, 360.0) / 90.0)) * 90) % 360,
					"props": _clean_props(type, o.get("props", {})),
				})
				next_id += 1
	if room_name.strip_edges() == "":
		room_name = fallback_name
	objects.insert(0, door)
	return {"name": room_name, "objects": objects}


## Nombre de sala que no pisa a una ya guardada: "Sala", "Sala (2)", ...
static func unique_name(base: String) -> String:
	var n := base.validate_filename().strip_edges()
	if n.is_empty():
		n = "sala"
	var candidate := n
	var i := 2
	while FileAccess.file_exists(DIR + "/" + candidate + ".json"):
		candidate = "%s (%d)" % [n, i]
		i += 1
	return candidate


static func load_author() -> String:
	var cfg := ConfigFile.new()
	if cfg.load(CONFIG_PATH) == OK:
		return str(cfg.get_value("perfil", "autor", ""))
	return ""


static func save_author(author: String) -> void:
	var cfg := ConfigFile.new()
	cfg.load(CONFIG_PATH)
	cfg.set_value("perfil", "autor", author)
	cfg.save(CONFIG_PATH)


static func list_rooms() -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(DIR)
	if d == null:
		return out
	for f in d.get_files():
		if f.ends_with(".json"):
			out.append(f.get_basename())
	out.sort()
	return out


## Devuelve avisos si la sala no se puede resolver (lista vacía = todo bien).
static func validate(data: Dictionary) -> Array[String]:
	var warnings: Array[String] = []
	var available := {}  # colores de llave que el jugador puede llegar a tener
	var chests: Array = []
	var door_needs := ""
	for o in data["objects"]:
		var props: Dictionary = o.get("props", {})
		match str(o["type"]):
			"llave":
				available[str(props.get("color", "Dorada"))] = true
			"cofre":
				chests.append(props)
			"puerta_salida":
				door_needs = str(props.get("needs", ""))

	var opened := {}
	var changed := true
	while changed:
		changed = false
		for i in chests.size():
			if opened.has(i):
				continue
			var needs := str(chests[i].get("needs", ""))
			if needs == "" or available.has(needs):
				opened[i] = true
				var gives := str(chests[i].get("gives", ""))
				if gives != "":
					available[gives] = true
				changed = true

	for i in chests.size():
		if not opened.has(i):
			warnings.append("Un cofre necesita la Llave %s, pero no hay forma de conseguirla." % str(chests[i].get("needs", "")))
	if door_needs != "" and not available.has(door_needs):
		warnings.append("La puerta necesita la Llave %s, pero no hay forma de conseguirla." % door_needs)
	return warnings
