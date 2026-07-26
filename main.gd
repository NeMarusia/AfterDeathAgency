extends Node2D

# === Переменные ===
var souls_freed := 0
var souls_per_second := 0
var upgrade_level := 0
var base_upgrade_cost := 10
var upgrade_growth := 1.5
var ghost_scene := preload("res://ghost.tscn")


# === onready-переменные ===
@onready var label := $UI/SoulsLabel
@onready var button := $UI/FreeSoulButton
@onready var soul_timer := $SoulTimer
@onready var buy_button := $UI/BuyPrinterButton
@onready var event_timer := $EventTimer
@onready var event_label := $UI/EventLabel
@onready var event_banner := $UI/EventBanner
@onready var banner_label := $UI/EventBanner/BannerLabel
@onready var click_sound := $ClickSound
@onready var paper_sound := $PaperSound
@onready var hmmF_sound := $HmmFSound
@onready var hmmM_sound := $HmmMSound
@onready var boooo_sound := $BooooSound
@onready var error_sound := $ErrorSound
@onready var portal_sound := $PortalSound
@onready var ghosts_container := $GhostsContainer


var rng := RandomNumberGenerator.new()
var ghost_scenes := []

func _ready():
	event_banner.visible = false  # скрываем баннер при старте
	button.pressed.connect(_on_button_pressed)
	soul_timer.timeout.connect(_on_soul_timer_timeout)
	buy_button.pressed.connect(_on_buy_printer_pressed)
	event_timer.timeout.connect(_on_event_timer_timeout)
	rng.randomize()
	start_event_timer()
	update_label()
	load_game()
	
func load_game():
	if FileAccess.file_exists("user://savegame.save"):
		var file = FileAccess.open("user://savegame.save", FileAccess.READ)
		if file:
			var save_data = file.get_var()
			file.close()

			souls_freed = save_data.get("souls_freed", 0)
			souls_per_second = save_data.get("souls_per_second", 0)
			upgrade_level = save_data.get("upgrade_level", 0)
			update_label()
		else:
			print("Ошибка при загрузке игры")
	else:
		print("Файл сохранения не найден")



func spawn_ghost():
	var ghost = ghost_scene.instantiate()

	var spawn_x = rng.randi_range(300, 1200)
	var spawn_y = rng.randi_range(450, 520)  
	ghost.position = Vector2(spawn_x, spawn_y)

	ghosts_container.add_child(ghost)


func _on_button_pressed():
	souls_freed += 1
	update_label()
	click_sound.play()
	spawn_ghost()

func _on_soul_timer_timeout():
	souls_freed += souls_per_second
	update_label()
	if souls_per_second > 0:
		spawn_ghost()	

func save_game():
	var save_data = {
		"souls_freed": souls_freed,
		"souls_per_second": souls_per_second,
		"upgrade_level": upgrade_level
	}
	var file = FileAccess.open("user://savegame.save", FileAccess.WRITE)
	if file:
		file.store_var(save_data)
		file.close()
	else:
		print("Ошибка при сохранении игры")

func update_label():
	var next_cost = int(base_upgrade_cost * pow(upgrade_level + 1, upgrade_growth))
	buy_button.text = "Купить духовод (+1) за %d душ" % next_cost
	label.text = "Застрявших душ отпущено: %d\n Душ в секунду: %d" % [souls_freed, souls_per_second]

func _on_buy_printer_pressed():
	var cost = int(base_upgrade_cost * pow(upgrade_level + 1, upgrade_growth))
	if souls_freed >= cost:
		paper_sound.play()
		souls_freed -= cost
		upgrade_level += 1
		souls_per_second += 1
		update_label()

func start_event_timer():
	var wait = rng.randi_range(10, 30)
	event_timer.wait_time = wait
	event_timer.start()

func play_random_hmm():
	if rng.randi_range(0, 1) == 0:
		hmmM_sound.play()
	else:
		hmmF_sound.play()

func _on_event_timer_timeout():
	var event_id = rng.randi_range(0, 8) 
	match event_id:
		0:
			event_label.text = "👻 Призрак бастует! Кнопка отключена..."
			error_sound.play()
			show_event_banner("📄 По внутреннему циркуляру №66/КЗ: взаимодействие с бастующими душами временно приостановлено.", 5.0)
			button.disabled = true
			buy_button.disabled = true
			await get_tree().create_timer(5.0).timeout
			button.disabled = false
			buy_button.disabled = false
			event_label.text = ""

		1:
			event_label.text = "☠️ Инспектор из Преисподней! Минус 5 душ"
			boooo_sound.play()
			var n = rng.randi_range(10, 100)
			show_event_banner("🧾 Аудит пройден. Обнаружено 5 лишних душ. Возврат произведён согласно приказу №%d-Б." % [n], 3.0)
			souls_freed = max(0, souls_freed - 5)
			update_label()
			await get_tree().create_timer(3.0).timeout
			event_label.text = ""

		2:
			event_label.text = "📚 Душа философа. Всё тормозит..."
			play_random_hmm()
			show_event_banner("📚 Душа требует определить смысл посмертия. Игра поставлена на паузу до прояснения.", 3.0)
			button.disabled = true
			soul_timer.stop()
			await get_tree().create_timer(3.0).timeout
			button.disabled = false
			soul_timer.start()
			event_label.text = ""

		3:
			var bonus = rng.randi_range(1, 20)
			souls_freed += bonus
			update_label()
			portal_sound.play()
			event_label.text = "🌪️ Поток душ усилился! +%d душ" % bonus
			var soul_banners = [
				"🌀 Поток усилился! Кто-то забыл запереть воронку!",
				"📦 Срочная партия душ с прошлой недели только что прибыла.",
				"🚚 Автокатафалк выгрузил контейнер с бонусами.",
				"📯 По ошибке открыли портал из бухгалтерии. Летят все, кто не подписался вовремя.",
				"🎁 Акция: «Приведи друга — получи +5 душ!»",
				"📊 Перерасчёт потусторонней нормы. Бонус начислен автоматически.",
				"🧾 Премия по итогам сверхнормативной загробной выработки.",
				"📡 Перехвачены души из соседнего измерения. Благословите переход."
			]
			var msg = soul_banners[rng.randi_range(0, soul_banners.size() - 1)]
			show_event_banner("%s (+%d душ)" % [msg, bonus], 3.0)
			await get_tree().create_timer(3.0).timeout
			event_label.text = ""

		4:
			event_label.text = "📎 Взрыв архива! Бумаги повсюду!"
			error_sound.play()
			show_event_banner("📚 Ошибка сортировки. Слишком много отчётности — 10 душ потерялись в документах.", 3.0)
			souls_freed = max(0, souls_freed - 10)
			update_label()
			await get_tree().create_timer(3.0).timeout
			event_label.text = ""

		5:
			event_label.text = "🕷️ Антикварный ревизор нашёл нарушения!"
			boooo_sound.play()
			show_event_banner("🧾 Древний инспектор обнаружил неучтённые души с 1886 года. -15 душ.", 3.0)
			souls_freed = max(0, souls_freed - 3)
			update_label()
			await get_tree().create_timer(3.0).timeout
			event_label.text = ""

		6:
			event_label.text = "🖋️ Призрак-чиновник активен! Производительность ↑"
			paper_sound.play()
			souls_per_second += 1
			var n = rng.randi_range(10, 100)
			show_event_banner("✒️ По приказу №Б-%d: выработка увеличена на 1 ед./сек." [n], 4.0)
			await get_tree().create_timer(4.0).timeout
			event_label.text = ""

		7:
			event_label.text = "🫖 Перерыв на чай. Всё замирает..."
			hmmM_sound.play()
			button.disabled = true
			soul_timer.stop()
			show_event_banner("☕ Призрачный чай заварен. Работа остановлена на 4 сек.", 4.0)
			await get_tree().create_timer(4.0).timeout
			button.disabled = false
			soul_timer.start()
			event_label.text = ""

		8:
			event_label.text = "🧼 Инвентаризация! Временное обнуление!"
			error_sound.play()
			show_event_banner("📋 Проверка: все души временно списаны. Не переживайте, они вернутся… когда-нибудь.", 3.0)
			souls_freed = 0
			update_label()
			await get_tree().create_timer(3.0).timeout
			event_label.text = ""

	start_event_timer()

func show_event_banner(text: String, duration := 3.0):
	event_banner.visible = true
	banner_label.text = text
	await get_tree().create_timer(duration).timeout
	event_banner.visible = false

func _notification(what):
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
