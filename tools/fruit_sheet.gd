extends SceneTree
## Draws every fruit and the bomb side by side and saves a picture, for judging the models.
##   xvfb-run -a godot --rendering-driver opengl3 --resolution 1400x520 -s tools/fruit_sheet.gd -- /path/out.png [yaw_degrees]

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	var path: String = args[0] if args.size() > 0 else "user://fruit_sheet.png"
	var yaw := deg_to_rad(float(args[1])) if args.size() > 1 else 0.0
	var world := Node3D.new()
	root.add_child(world)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color8(10, 11, 20)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.6
	var we := WorldEnvironment.new()
	we.environment = env
	world.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 25, 0)
	sun.light_energy = 0.9
	world.add_child(sun)
	var kinds: Array[String] = ["apple", "banana", "orange", "cherry", "strawberry", "pear", "bomb"]
	for i in kinds.size():
		var item := Fruit.build(kinds[i])
		item.position = Vector3((i - 3) * 2.3, 0, 0)
		item.rotation.y = yaw
		world.add_child(item)
	var camera := Camera3D.new()
	camera.fov = 30.0
	camera.position = Vector3(0, 0.1, 9.5)
	world.add_child(camera)
	_shoot.call_deferred(path)


func _shoot(path: String) -> void:
	for i in 4:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(path)
	quit()
