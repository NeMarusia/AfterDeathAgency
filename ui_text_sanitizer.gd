extends Node

# Оригинальные шрифты игры не содержат emoji-глифов.
# Этот автозагрузочный узел удаляет только emoji и variation selectors,
# сохраняя кириллицу, цифры, пунктуацию и исходное оформление.

var _sanitize_timer: Timer


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_sanitize_timer = Timer.new()
	_sanitize_timer.wait_time = 0.08
	_sanitize_timer.autostart = true
	_sanitize_timer.timeout.connect(_sanitize_current_scene)
	add_child(_sanitize_timer)
	call_deferred("_sanitize_current_scene")


func _sanitize_current_scene() -> void:
	var scene := get_tree().current_scene
	if scene != null:
		_sanitize_node(scene)


func _sanitize_node(node: Node) -> void:
	if node is Label or node is Button or node is RichTextLabel:
		var current_text: String = node.text
		var clean_text := _remove_unsupported_symbols(current_text)
		if clean_text != current_text:
			node.text = clean_text

	for child: Node in node.get_children():
		_sanitize_node(child)


func _remove_unsupported_symbols(value: String) -> String:
	var result := ""
	for character: String in value:
		var codepoint := character.unicode_at(0)
		if _is_emoji_or_selector(codepoint):
			continue
		result += character

	while result.contains("  "):
		result = result.replace("  ", " ")
	return result.strip_edges()


func _is_emoji_or_selector(codepoint: int) -> bool:
	if codepoint == 0xFE0F or codepoint == 0x200D:
		return true
	if codepoint >= 0x1F000 and codepoint <= 0x1FAFF:
		return true
	if codepoint >= 0x2600 and codepoint <= 0x27BF:
		return true
	return false
