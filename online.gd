extends Node
## Cliente para compartir salas con un servidor Supabase (API REST).
## Todas las funciones son asíncronas: se usan con `await` y devuelven {"ok": bool, ...}.

const Config = preload("res://online_config.gd")
const RoomData = preload("res://room_data.gd")


func is_configured() -> bool:
	var url: String = Config.SUPABASE_URL
	var key: String = Config.SUPABASE_ANON_KEY
	return url.begins_with("https://") and not url.contains("TU-PROYECTO") \
		and key != "" and not key.begins_with("TU-")


func _headers(extra: Array = []) -> PackedStringArray:
	var key: String = Config.SUPABASE_ANON_KEY
	var h := PackedStringArray(["apikey: " + key, "Content-Type: application/json"])
	if key.begins_with("eyJ"): # clave antigua (JWT)
		h.append("Authorization: Bearer " + key)
	for e in extra:
		h.append(str(e))
	return h


func _request(method: int, path: String, body := "", extra: Array = []) -> Dictionary:
	var http := HTTPRequest.new()
	http.timeout = 15.0
	add_child(http)
	var url: String = Config.SUPABASE_URL.rstrip("/") + "/rest/v1/" + path
	var err := http.request(url, _headers(extra), method, body)
	if err != OK:
		http.queue_free()
		return {"ok": false, "error": "no se pudo iniciar la conexión"}
	var res: Array = await http.request_completed
	http.queue_free()
	var result: int = res[0]
	var code: int = res[1]
	var text: String = (res[3] as PackedByteArray).get_string_from_utf8()
	if result != HTTPRequest.RESULT_SUCCESS:
		return {"ok": false, "error": "sin conexión con el servidor"}
	if code < 200 or code >= 300:
		return {"ok": false, "error": "el servidor respondió con el código %d" % code}
	var parsed = null
	if text.strip_edges() != "":
		parsed = JSON.parse_string(text)
	return {"ok": true, "data": parsed}


## Sube una sala al servidor.
func publish_room(room: Dictionary, author: String) -> Dictionary:
	var clean := RoomData.sanitize(room, str(room.get("name", "Sala")))
	var payload := {
		"name": str(clean["name"]).substr(0, 40),
		"author": author.substr(0, 30),
		"data": clean,
	}
	return await _request(HTTPClient.METHOD_POST, "rooms", JSON.stringify(payload),
		["Prefer: return=minimal"])


## Lista las salas más recientes: {"ok": true, "data": [{id, name, author, created_at}, ...]}
func list_rooms(limit := 40) -> Dictionary:
	var r: Dictionary = await _request(HTTPClient.METHOD_GET,
		"rooms?select=id,name,author,created_at&order=created_at.desc&limit=%d" % limit)
	if r["ok"] and typeof(r["data"]) != TYPE_ARRAY:
		return {"ok": false, "error": "respuesta inesperada del servidor"}
	return r


## Descarga una sala. La sala se limpia y valida antes de devolverla.
func download_room(id: String) -> Dictionary:
	var r: Dictionary = await _request(HTTPClient.METHOD_GET,
		"rooms?id=eq.%s&select=name,author,data&limit=1" % id.uri_encode())
	if not r["ok"]:
		return r
	var rows = r["data"]
	if typeof(rows) != TYPE_ARRAY or rows.is_empty():
		return {"ok": false, "error": "la sala ya no existe"}
	var row = rows[0]
	if typeof(row) != TYPE_DICTIONARY:
		return {"ok": false, "error": "respuesta inesperada del servidor"}
	return {
		"ok": true,
		"data": RoomData.sanitize(row.get("data"), str(row.get("name", "Sala"))),
		"author": str(row.get("author", "")),
	}
