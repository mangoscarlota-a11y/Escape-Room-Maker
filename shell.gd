extends RefCounted
## Estructura fija de las salas creadas: suelo, paredes y hueco para la puerta de salida (pared norte).

const RoomBuilder = preload("res://room_builder.gd")

const HALF := 4.0     # la sala mide 8 x 8 m por dentro
const WALL_H := 3.0
const SPAWN := Vector3(0, 0.1, 3.4)


static func build(play: bool) -> Node3D:
	var root := Node3D.new()
	root.name = "Sala"
	var wall := Color(0.86, 0.82, 0.74)
	var size := HALF * 2.0 + 0.4

	RoomBuilder.box(root, Vector3(size, 0.2, size), Vector3(0, -0.1, 0), Color(0.5, 0.34, 0.2), 0.6)
	RoomBuilder.box(root, Vector3(0.2, WALL_H, size), Vector3(-HALF - 0.1, WALL_H / 2.0, 0), wall)
	RoomBuilder.box(root, Vector3(0.2, WALL_H, size), Vector3(HALF + 0.1, WALL_H / 2.0, 0), wall)
	RoomBuilder.box(root, Vector3(size, WALL_H, 0.2), Vector3(0, WALL_H / 2.0, HALF + 0.1), wall)
	# Pared norte con un hueco de 1.2 m para la puerta
	RoomBuilder.box(root, Vector3(3.6, WALL_H, 0.2), Vector3(-2.4, WALL_H / 2.0, -HALF - 0.1), wall)
	RoomBuilder.box(root, Vector3(3.6, WALL_H, 0.2), Vector3(2.4, WALL_H / 2.0, -HALF - 0.1), wall)
	RoomBuilder.box(root, Vector3(1.2, 0.9, 0.2), Vector3(0, 2.55, -HALF - 0.1), wall)

	if play:
		RoomBuilder.box(root, Vector3(size, 0.2, size), Vector3(0, 3.1, 0), Color(0.93, 0.91, 0.87))
		var light := OmniLight3D.new()
		light.position = Vector3(0, 2.7, 0)
		light.light_color = Color(1.0, 0.95, 0.85)
		light.light_energy = 1.1
		light.omni_range = 12.0
		light.shadow_enabled = true
		root.add_child(light)
	else:
		# Marca verde donde empieza el jugador
		var marker := MeshInstance3D.new()
		var mm := BoxMesh.new()
		mm.size = Vector3(0.9, 0.02, 0.9)
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(0.2, 0.7, 0.35)
		mm.material = mat
		marker.mesh = mm
		marker.position = Vector3(SPAWN.x, 0.011, SPAWN.z)
		root.add_child(marker)
		var l3 := Label3D.new()
		l3.text = "INICIO"
		l3.font_size = 48
		l3.pixel_size = 0.005
		l3.rotation_degrees = Vector3(-90, 0, 0)
		l3.position = Vector3(SPAWN.x, 0.03, SPAWN.z)
		root.add_child(l3)

	return root
