extends Node2D

const SAVE_PATH := "user://savegame.save"
const SAVE_VERSION := 2
const AUTOSAVE_SECONDS := 20.0
const MAX_OFFLINE_SECONDS := 8 * 60 * 60
const RARE_SOUL_CHANCE := 0.04
const RARE_SOUL_REWARD := 5
const ACHIEVEMENT_COUNT := 6

# === Базовая экономика оригинальной игры ===
var souls_freed := 0
var souls_per_second := 0
var upgrade_level := 0
var base_upgrade_cost := 10
var upgrade_growth := 1.5
var ghost_scene := preload("res://ghost.tscn")

# === Новая прогрессия, не меняющая исходный игровой цикл ===
var total_souls_freed := 0
var total_clicks := 0
var rare_souls_found := 0
var play_seconds := 0
var unlocked_achievements: Array[String] = []

var rng := RandomNumberGenerator.new()
var autosave_timer: Timer
var playtime_timer: Timer
var banner_generation := 0
var notice_queue: Array[Dictionary] = []
var notice_queue_running := false

# === Исходные узлы сцены ===
@onready var label: Label = $UI/SoulsLabel
@onready var stats_label: Label = $UI/update_label
@onready var button: Button = $UI/FreeSoulButton
@onready var soul_timer: Timer = $SoulTimer
@onready var buy_button: Button = $UI/BuyPrinterButton
@onready var event_timer: Timer = $EventTimer
@onready var event_label: Label = $UI/EventLabel
@onready var event_banner: Panel = $UI/EventBanner
@onready var banner_label: Label = $UI/EventBanner/BannerLabel
@onready var click_sound: AudioStreamPlayer = $ClickSound
@onready var paper_sound: AudioStreamPlayer = $PaperSound
@onready var hmmF_sound: AudioStreamPlayer = $HmmFSound
@onready var hmmM_sound: AudioStreamPlayer = $HmmMSound
@onready var boooo_sound: AudioStreamPlayer = $BooooSound
@onready var error_sound: AudioStreamPlayer = $ErrorSound
@onready var portal_sound: AudioStreamPlayer = $PortalSound
@onready var ghosts_container: Sprite2D = $GhostsContainer


func _ready() -> void:
	event_banner.visible = false
	stats_label.add_theme_font_size_override("font_size", 28)

	button.pressed.connect(_on_button_pressed)
	soul_timer.timeout.connect(_on_soul_timer_timeout)
	buy_button.pressed.connect(_on_buy_printer_pressed)
	event_timer.timeout.connect(_on_event_timer_timeout)

	rng.randomize()
	load_game()
	_configure_runtime_timers()
	start_event_timer()
	update_label()
	_check_achievements()


func _configure_runtime_timers() -> void:
	autosave_timer = Timer.new()
	autosave_timer.name = "AutosaveTimer"
	autosave_timer.wait_time = AUTOSAVE_SECONDS
	autosave_timer.autostart = true
	autosave_timer.timeout.connect(save_game)
	add_child(autosave_timer)

	playtime_timer = Timer.new()
	playtime_timer.name = "PlaytimeTimer"
	playtime_timer.wait_time = 1.0
	playtime_timer.autostart = true
	playtime_timer.timeout.connect(_on_playtime_tick)
	add_child(playtime_timer)


func _on_playtime_tick() -> void:
	play_seconds += 1


func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		print("Файл сохранения не найден")
		return

	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if file == null:
		print("Ошибка при загрузке игры")
		return

	var loaded_data: Variant = file.get_var()
	file.close()
	if not loaded_data is Dictionary:
		print("Файл сохранения повреждён")
		return

	var save_data: Dictionary = loaded_data
	souls_freed = int(save_data.get("souls_freed", 0))
	souls_per_second = int(save_data.get("souls_per_second", 0))
	upgrade_level = int(save_data.get("upgrade_level", 0))
	total_souls_freed = max(int(save_data.get("total_souls_freed", souls_freed)), souls_freed)
	total_clicks = int(save_data.get("total_clicks", 0))
	rare_souls_found = int(save_data.get("rare_souls_found", 0))
	play_seconds = int(save_data.get("play_seconds", 0))

	unlocked_achievements.clear()
	var saved_achievements: Array = save_data.get("unlocked_achievements", [])
	for achievement: Variant in saved_achievements:
		unlocked_achievements.append(str(achievement))

	var now: int = int(Time.get_unix_time_from_system())
	var last_save: int = int(save_data.get("last_save_unix", now))
	var elapsed: int = clampi(now - last_save, 0, MAX_OFFLINE_SECONDS)
	var offline_income: int = elapsed * souls_per_second
	if offline_income > 0:
		souls_freed += offline_income
		total_souls_freed += offline_income
		call_deferred("_announce_offline_income", offline_income, elapsed)


func _announce_offline_income(income: int, elapsed: int) -> void:
	_queue_notice(
		"🕰️ Пока ведомство работало без вас, духоводы отпустили %d душ за %s." % [income, _format_duration(elapsed)],
		4.5
	)


func _format_duration(seconds: int) -> String:
	var hours: int = int(seconds / 3600)
	var minutes: int = int((seconds % 3600) / 60)
	if hours > 0:
		return "%d ч %d мин" % [hours, minutes]
	if minutes > 0:
		return "%d мин" % minutes
	return "%d сек" % seconds


func save_game() -> void:
	var save_data := {
		"save_version": SAVE_VERSION,
		"souls_freed": souls_freed,
		"souls_per_second": souls_per_second,
		"upgrade_level": upgrade_level,
		"total_souls_freed": total_souls_freed,
		"total_clicks": total_clicks,
		"rare_souls_found": rare_souls_found,
		"play_seconds": play_seconds,
		"unlocked_achievements": unlocked_achievements,
		"last_save_unix": int(Time.get_unix_time_from_system())
	}

	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file == null:
		print("Ошибка при сохранении игры")
		return
	file.store_var(save_data)
	file.close()


func spawn_ghost(is_rare: bool = false) -> void:
	var ghost := ghost_scene.instantiate()
	ghost.position = Vector2(rng.randi_range(300, 1200), rng.randi_range(450, 520))
	ghosts_container.add_child(ghost)

	# Редкая душа использует тот же авторский спрайт, только с золотистым свечением.
	if is_rare:
		ghost.modulate = Color(1.0, 0.82, 0.35, 1.0)
		ghost.scale *= 1.2
		ghost.z_index = 2


func _on_button_pressed() -> void:
	var is_rare: bool = rng.randf() < RARE_SOUL_CHANCE
	var reward: int = RARE_SOUL_REWARD if is_rare else 1

	souls_freed += reward
	total_souls_freed += reward
	total_clicks += 1

	if is_rare:
		rare_souls_found += 1
		portal_sound.play()
		_queue_notice("✨ Редкая сияющая душа! Ведомство начислило +%d душ." % reward, 3.0)
	else:
		click_sound.play()

	spawn_ghost(is_rare)
	update_label()
	_check_achievements()


func _on_soul_timer_timeout() -> void:
	if souls_per_second <= 0:
		return

	souls_freed += souls_per_second
	total_souls_freed += souls_per_second
	spawn_ghost()
	update_label()
	_check_achievements()


func update_label() -> void:
	var next_cost: int = int(base_upgrade_cost * pow(upgrade_level + 1, upgrade_growth))
	buy_button.text = "Купить духовод (+1) за %d душ" % next_cost
	label.text = "Застрявших душ отпущено: %d\n Душ в секунду: %d" % [souls_freed, souls_per_second]
	stats_label.text = "Ранг: %s  •  Всего: %d\nКликов: %d  •  Редких: %d  •  Достижений: %d/%d" % [
		_get_agency_rank(),
		total_souls_freed,
		total_clicks,
		rare_souls_found,
		unlocked_achievements.size(),
		ACHIEVEMENT_COUNT
	]


func _get_agency_rank() -> String:
	if total_souls_freed >= 5000:
		return "Замминистра"
	if total_souls_freed >= 1000:
		return "Начальник смены"
	if total_souls_freed >= 250:
		return "Старший духовод"
	if total_souls_freed >= 50:
		return "Делопроизводитель"
	return "Стажёр"


func _on_buy_printer_pressed() -> void:
	var cost: int = int(base_upgrade_cost * pow(upgrade_level + 1, upgrade_growth))
	if souls_freed < cost:
		error_sound.play()
		_queue_notice("📎 Недостаточно душ. Бухгалтерия отклонила заявку на духовод.", 2.5)
		return

	paper_sound.play()
	souls_freed -= cost
	upgrade_level += 1
	souls_per_second += 1
	update_label()
	_check_achievements()
	save_game()


func _check_achievements() -> void:
	_try_unlock_achievement("first_soul", total_souls_freed >= 1, "Первая проводка")
	_try_unlock_achievement("hundred_souls", total_souls_freed >= 100, "Сто дел без замечаний")
	_try_unlock_achievement("thousand_souls", total_souls_freed >= 1000, "Тысячная запись в реестре")
	_try_unlock_achievement("first_guide", upgrade_level >= 1, "Первый духовод")
	_try_unlock_achievement("five_per_second", souls_per_second >= 5, "Поточная канцелярия")
	_try_unlock_achievement("rare_soul", rare_souls_found >= 1, "Редкий экземпляр")


func _try_unlock_achievement(id: String, condition: bool, title: String) -> void:
	if not condition or unlocked_achievements.has(id):
		return

	unlocked_achievements.append(id)
	update_label()
	save_game()
	_queue_notice("🏆 Достижение: «%s»" % title, 3.2)


func _queue_notice(text: String, duration: float = 3.0) -> void:
	notice_queue.append({"text": text, "duration": duration})
	if not notice_queue_running:
		call_deferred("_process_notice_queue")


func _process_notice_queue() -> void:
	if notice_queue_running:
		return

	notice_queue_running = true
	while not notice_queue.is_empty():
		while event_banner.visible:
			await get_tree().create_timer(0.2).timeout

		var notice: Dictionary = notice_queue.pop_front()
		await show_event_banner(str(notice.get("text", "")), float(notice.get("duration", 3.0)))
		await get_tree().create_timer(0.15).timeout
	notice_queue_running = false


func start_event_timer() -> void:
	event_timer.wait_time = rng.randi_range(10, 30)
	event_timer.start()


func play_random_hmm() -> void:
	if rng.randi_range(0, 1) == 0:
		hmmM_sound.play()
	else:
		hmmF_sound.play()


func _on_event_timer_timeout() -> void:
	var event_id: int = rng.randi_range(0, 8)
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
			var order_number: int = rng.randi_range(10, 100)
			show_event_banner("🧾 Аудит пройден. Обнаружено 5 лишних душ. Возврат произведён согласно приказу №%d-Б." % order_number, 3.0)
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
			var bonus: int = rng.randi_range(1, 20)
			souls_freed += bonus
			total_souls_freed += bonus
			update_label()
			_check_achievements()
			portal_sound.play()
			event_label.text = "🌪️ Поток душ усилился! +%d душ" % bonus
			var soul_banners := [
				"🌀 Поток усилился! Кто-то забыл запереть воронку!",
				"📦 Срочная партия душ с прошлой недели только что прибыла.",
				"🚚 Автокатафалк выгрузил контейнер с бонусами.",
				"📯 По ошибке открыли портал из бухгалтерии. Летят все, кто не подписался вовремя.",
				"🎁 Акция: «Приведи друга — получи +5 душ!»",
				"📊 Перерасчёт потусторонней нормы. Бонус начислен автоматически.",
				"🧾 Премия по итогам сверхнормативной загробной выработки.",
				"📡 Перехвачены души из соседнего измерения. Благословите переход."
			]
			var message: String = soul_banners[rng.randi_range(0, soul_banners.size() - 1)]
			show_event_banner("%s (+%d душ)" % [message, bonus], 3.0)
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
			show_event_banner("🧾 Древний инспектор обнаружил неучтённые души с 1886 года. -3 души.", 3.0)
			souls_freed = max(0, souls_freed - 3)
			update_label()
			await get_tree().create_timer(3.0).timeout
			event_label.text = ""

		6:
			event_label.text = "🖋️ Призрак-чиновник активен! Производительность ↑"
			paper_sound.play()
			souls_per_second += 1
			var order_number: int = rng.randi_range(10, 100)
			show_event_banner("✒️ По приказу №Б-%d: выработка увеличена на 1 ед./сек." % order_number, 4.0)
			update_label()
			_check_achievements()
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


func show_event_banner(text: String, duration: float = 3.0) -> void:
	banner_generation += 1
	var current_generation: int = banner_generation
	event_banner.visible = true
	banner_label.text = text
	await get_tree().create_timer(duration).timeout
	if current_generation == banner_generation:
		event_banner.visible = false


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		save_game()
		get_tree().quit()
	elif what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_game()
