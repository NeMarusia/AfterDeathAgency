extends SceneTree

const REQUIRED_RESOURCES := [
	"res://Ofice.png",
	"res://ghost.tscn",
	"res://ghost.gd",
	"res://sprites/ghosts/Ghost_happy.png",
	"res://sprites/ghosts/Ghost_evil.png",
	"res://sprites/ghosts/Ghost_surprised.png",
	"res://sprites/ghosts/Ghost_sad.png",
	"res://sound/click.wav",
	"res://sound/paper.wav",
	"res://sound/Fone.mp3",
	"res://fonts/Amatic_SC/AmaticSC-Bold.ttf",
	"res://fonts/Shantell_Sans/static/ShantellSans-SemiBold.ttf"
]

const REQUIRED_MAIN_NODES := [
	"Background",
	"UI/SoulsLabel",
	"UI/update_label",
	"UI/EventLabel",
	"UI/EventBanner",
	"UI/FreeSoulButton",
	"UI/BuyPrinterButton",
	"GhostsContainer",
	"SoulTimer",
	"EventTimer",
	"AmbientMusic"
]

const REQUIRED_GHOST_NODES := [
	"happy",
	"evil",
	"surprised",
	"sad"
]


func _init() -> void:
	var failures: Array[String] = []

	for resource_path: String in REQUIRED_RESOURCES:
		if not ResourceLoader.exists(resource_path):
			failures.append("Missing original resource: %s" % resource_path)

	_validate_scene("res://main.tscn", REQUIRED_MAIN_NODES, failures)
	_validate_scene("res://ghost.tscn", REQUIRED_GHOST_NODES, failures)

	if failures.is_empty():
		print("Original pixel-art game smoke test passed.")
		quit(0)
		return

	for failure: String in failures:
		push_error(failure)
	quit(1)


func _validate_scene(scene_path: String, required_nodes: Array, failures: Array[String]) -> void:
	var resource: Resource = load(scene_path)
	var packed_scene := resource as PackedScene
	if packed_scene == null:
		failures.append("Unable to load scene: %s" % scene_path)
		return

	var instance: Node = packed_scene.instantiate()
	if instance == null:
		failures.append("Unable to instantiate scene: %s" % scene_path)
		return

	for node_path: String in required_nodes:
		if instance.get_node_or_null(NodePath(node_path)) == null:
			failures.append("Missing node %s in %s" % [node_path, scene_path])

	instance.free()
