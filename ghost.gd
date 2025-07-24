extends Node2D

var sprites := []
var rng := RandomNumberGenerator.new()

func _ready():
	rng.randomize()
	scale = Vector2(0.1, 0.1) 
	sprites = [
		$happy,
		$sad,
		$evil,
		$surprised
	]

	# Прячем все
	for s in sprites:
		s.visible = false

	# Показываем один случайный
	var random_sprite = sprites[rng.randi_range(0, sprites.size() - 1)]
	random_sprite.visible = true

	# Анимация появления-пропадания
	var tween = create_tween()
	var target_y = position.y - 100
	tween.tween_property(self, "position:y", target_y, 1.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "modulate:a", 0.0, 1.5)
	tween.finished.connect(queue_free)
