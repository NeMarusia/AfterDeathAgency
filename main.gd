extends Control

const SAVE_PATH := "user://after_death_agency_v2.save"
const SAVE_VERSION := 2
const AUTOSAVE_SECONDS := 20.0

const C_BG := Color("11131a")
const C_PANEL := Color("1b1f2a")
const C_PANEL_2 := Color("242a38")
const C_TEXT := Color("f3ead8")
const C_MUTED := Color("aaa69d")
const C_GOLD := Color("d8ac57")
const C_SOUL := Color("7fe4d2")
const C_RED := Color("da6f72")
const C_PURPLE := Color("a894e8")

var souls := 25.0
var reputation := 50
var stamps := 0
var day := 1
var processed_today := 0
var total_processed := 0
var combo := 0
var offline_earned := 0.0
var current_case: Dictionary = {}
var case_queue: Array[Dictionary] = []
var departments := [
	{"name":"Приёмная","level":1,"base":18.0,"rate":0.20,"description":"Регистрирует прибывшие души."},
	{"name":"Архив","level":0,"base":65.0,"rate":0.55,"description":"Находит документы, которых никогда не существовало."},
	{"name":"Судебный отдел","level":0,"base":180.0,"rate":1.40,"description":"Снижает штрафы за спорные решения."},
	{"name":"Сопровождение","level":0,"base":520.0,"rate":3.80,"description":"Автоматически закрывает простые дела."},
	{"name":"Контроль качества","level":0,"base":1450.0,"rate":9.50,"description":"Повышает репутацию и доход."}
]
var achievements := {}
var log_lines: Array[String] = []
var rng := RandomNumberGenerator.new()
var autosave_accum := 0.0
var passive_accum := 0.0
var event_accum := 0.0
var event_interval := 18.0
var boost_until := 0

var souls_label: Label
var rep_label: Label
var day_label: Label
var income_label: Label
var case_name: Label
var case_details: Label
var case_quote: Label
var queue_label: Label
var progress_label: Label
var event_label: Label
var log_label: RichTextLabel
var department_box: VBoxContainer
var decision_buttons: Array[Button] = []
var boost_button: Button
var reset_button: Button

var first_names := ["Аркадий","Вера","Тимофей","Зинаида","Глеб","Лидия","Руслан","Нина","Вадим","Аглая","Семён","Эмма"]
var last_names := ["Безочередин","Скрепкина","Печать-Поставь","Недописан","Справочникова","Талонов","Чернильная","Крайний"]
var causes := [
	"пытался починить микроволновку вилкой",
	"прочитал пользовательское соглашение до конца",
	"нажал «обновить всё» перед дедлайном",
	"встал в очередь не в то окно",
	"доказал бухгалтерии, что она ошиблась",
	"забыл выключить утюг, но вспомнил слишком поздно",
	"решил собрать шкаф без инструкции",
	"ответил «вам тоже» на соболезнования"
]
var quirks := [
	"требует вызвать начальство",
	"принёс справку без синей печати",
	"уверяет, что запись была на вчера",
	"пытается пройти по льготной очереди",
	"отказывается признавать факт смерти",
	"оставил документы в другом измерении",
	"слишком вежлив, это подозрительно",
	"знает номер внутреннего приказа"
]
var quotes := [
	"Я только спросить.",
	"У меня там парковка оплачена.",
	"Это займёт не больше минуты.",
	"Мне сказали, что сюда без записи.",
	"Можно я сначала позвоню знакомому?",
	"Я всё заполнил, но ручка была не та."
]
var destinations := ["Светлый сектор","Нижний архив","Чистилище"]

func _ready() -> void:
	rng.randomize()
	_build_ui()
	_load_game()
	_fill_queue()
	_next_case()
	_refresh_all()
	_log("Смена началась. Министерство посмертных дел снова делает вид, что всё под контролем.")
	if offline_earned > 0:
		_log("За время отсутствия агентство обработало дел на %.0f душ." % offline_earned)
		_show_notice("Офлайн-доход: +%.0f душ" % offline_earned, C_SOUL)

func _process(delta: float) -> void:
	autosave_accum += delta
	passive_accum += delta
	event_accum += delta
	if passive_accum >= 1.0:
		var seconds := floori(passive_accum)
		passive_accum -= seconds
		souls += _income_per_second() * seconds
		if departments[3].level > 0:
			total_processed += int(departments[3].level * seconds / 10.0)
		_refresh_header()
	if autosave_accum >= AUTOSAVE_SECONDS:
		autosave_accum = 0.0
		_save_game()
	if event_accum >= event_interval:
		event_accum = 0.0
		event_interval = rng.randf_range(16.0, 30.0)
		_trigger_event()
	if Time.get_unix_time_from_system() < boost_until:
		boost_button.text = "Ускорение активно: %dс" % int(boost_until - Time.get_unix_time_from_system())
	else:
		boost_button.text = "Удвоить доход на 2 минуты"

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = C_BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	add_child(margin)

	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 14)
	margin.add_child(root)
	root.add_child(_build_header())

	event_label = Label.new()
	event_label.text = "ВНУТРЕННИЙ ЦИРКУЛЯР: соблюдайте спокойствие и нумерацию приложений."
	event_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	event_label.add_theme_font_size_override("font_size", 17)
	event_label.add_theme_color_override("font_color", C_GOLD)
	root.add_child(event_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var left := _panel()
	left.custom_minimum_size = Vector2(540, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(left)
	left.get_child(0).add_child(_build_case_area())

	var right := _panel()
	right.custom_minimum_size = Vector2(430, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(right)
	right.get_child(0).add_child(_build_department_area())
	root.add_child(_build_footer())

func _build_header() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.y = 94
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.get_child(0).add_child(row)
	var title_box := VBoxContainer.new()
	title_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(title_box)
	var title := Label.new()
	title.text = "АГЕНТСТВО ПОСТСМЕРТНОГО СОПРОВОЖДЕНИЯ"
	title.add_theme_font_size_override("font_size", 25)
	title.add_theme_color_override("font_color", C_TEXT)
	title_box.add_child(title)
	var subtitle := Label.new()
	subtitle.text = "Отделение №404 · Ваше дело уже потеряно"
	subtitle.add_theme_font_size_override("font_size", 15)
	subtitle.add_theme_color_override("font_color", C_MUTED)
	title_box.add_child(subtitle)
	souls_label = _stat_label()
	rep_label = _stat_label()
	day_label = _stat_label()
	income_label = _stat_label()
	row.add_child(souls_label)
	row.add_child(rep_label)
	row.add_child(day_label)
	row.add_child(income_label)
	return panel

func _build_case_area() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	var top := HBoxContainer.new()
	queue_label = Label.new()
	queue_label.add_theme_font_size_override("font_size", 16)
	queue_label.add_theme_color_override("font_color", C_MUTED)
	top.add_child(queue_label)
	progress_label = Label.new()
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	progress_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress_label.add_theme_font_size_override("font_size", 16)
	progress_label.add_theme_color_override("font_color", C_SOUL)
	top.add_child(progress_label)
	box.add_child(top)

	var dossier := PanelContainer.new()
	dossier.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dossier.add_theme_stylebox_override("panel", _style(Color("efe5ce"), Color("b49a67"), 10, 2))
	var dossier_margin := MarginContainer.new()
	dossier_margin.add_theme_constant_override("margin_left", 22)
	dossier_margin.add_theme_constant_override("margin_right", 22)
	dossier_margin.add_theme_constant_override("margin_top", 18)
	dossier_margin.add_theme_constant_override("margin_bottom", 18)
	dossier.add_child(dossier_margin)
	var dossier_box := VBoxContainer.new()
	dossier_box.add_theme_constant_override("separation", 12)
	dossier_margin.add_child(dossier_box)
	var file_tag := Label.new()
	file_tag.text = "ЛИЧНОЕ ДЕЛО / ФОРМА ПС-13"
	file_tag.add_theme_font_size_override("font_size", 14)
	file_tag.add_theme_color_override("font_color", Color("6d624f"))
	dossier_box.add_child(file_tag)
	case_name = Label.new()
	case_name.add_theme_font_size_override("font_size", 30)
	case_name.add_theme_color_override("font_color", Color("24211d"))
	dossier_box.add_child(case_name)
	case_details = Label.new()
	case_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	case_details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	case_details.add_theme_font_size_override("font_size", 19)
	case_details.add_theme_color_override("font_color", Color("363028"))
	dossier_box.add_child(case_details)
	case_quote = Label.new()
	case_quote.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	case_quote.add_theme_font_size_override("font_size", 20)
	case_quote.add_theme_color_override("font_color", Color("66513d"))
	dossier_box.add_child(case_quote)
	box.add_child(dossier)
	var instruction := Label.new()
	instruction.text = "Определите маршрут. Ошибки будут аккуратно записаны в ваше личное дело."
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	instruction.add_theme_color_override("font_color", C_MUTED)
	box.add_child(instruction)
	var decisions := HBoxContainer.new()
	decisions.add_theme_constant_override("separation", 10)
	for i in 3:
		var button := _button(destinations[i], [C_SOUL, C_RED, C_PURPLE][i])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.pressed.connect(_decide.bind(i))
		decisions.add_child(button)
		decision_buttons.append(button)
	box.add_child(decisions)
	return box

func _build_department_area() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	var title := Label.new()
	title.text = "ОТДЕЛЫ АГЕНТСТВА"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", C_TEXT)
	box.add_child(title)
	var hint := Label.new()
	hint.text = "Развивайте отделы, чтобы работа шла даже без вашего героического присутствия."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_color_override("font_color", C_MUTED)
	box.add_child(hint)
	department_box = VBoxContainer.new()
	department_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	department_box.add_theme_constant_override("separation", 8)
	box.add_child(department_box)
	boost_button = _button("Удвоить доход на 2 минуты", C_GOLD)
	boost_button.pressed.connect(_rewarded_boost)
	box.add_child(boost_button)
	return box

func _build_footer() -> Control:
	var panel := _panel()
	panel.custom_minimum_size.y = 132
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	panel.get_child(0).add_child(row)
	log_label = RichTextLabel.new()
	log_label.bbcode_enabled = true
	log_label.fit_content = false
	log_label.scroll_active = true
	log_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	log_label.add_theme_font_size_override("normal_font_size", 15)
	log_label.add_theme_color_override("default_color", C_MUTED)
	row.add_child(log_label)
	var actions := VBoxContainer.new()
	actions.custom_minimum_size.x = 260
	row.add_child(actions)
	var daily := _button("Закрыть рабочий день", C_SOUL)
	daily.pressed.connect(_close_day)
	actions.add_child(daily)
	var achievements_button := _button("Показать достижения", C_PURPLE)
	achievements_button.pressed.connect(_show_achievements)
	actions.add_child(achievements_button)
	reset_button = _button("Новая карьера", C_RED)
	reset_button.pressed.connect(_confirm_reset)
	actions.add_child(reset_button)
	return panel

func _panel() -> PanelContainer:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(C_PANEL, Color("333a4b"), 12, 1))
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 16)
	margin.add_theme_constant_override("margin_right", 16)
	margin.add_theme_constant_override("margin_top", 14)
	margin.add_theme_constant_override("margin_bottom", 14)
	panel.add_child(margin)
	return panel

func _style(color: Color, border: Color, radius: int, width: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.border_color = border
	style.set_border_width_all(width)
	style.set_corner_radius_all(radius)
	return style

func _button(text_value: String, accent: Color) -> Button:
	var button := Button.new()
	button.text = text_value
	button.custom_minimum_size.y = 48
	button.add_theme_font_size_override("font_size", 16)
	button.add_theme_color_override("font_color", C_TEXT)
	button.add_theme_stylebox_override("normal", _style(C_PANEL_2, accent.darkened(0.35), 8, 1))
	button.add_theme_stylebox_override("hover", _style(accent.darkened(0.45), accent, 8, 2))
	button.add_theme_stylebox_override("pressed", _style(accent.darkened(0.6), accent, 8, 2))
	return button

func _stat_label() -> Label:
	var label := Label.new()
	label.custom_minimum_size.x = 138
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_color", C_TEXT)
	return label

func _fill_queue() -> void:
	while case_queue.size() < 5:
		case_queue.append(_generate_case())

func _generate_case() -> Dictionary:
	var difficulty := rng.randi_range(1, 4)
	return {
		"name":"%s %s" % [first_names.pick_random(), last_names.pick_random()],
		"age":rng.randi_range(19, 94),
		"cause":causes.pick_random(),
		"quirk":quirks.pick_random(),
		"quote":quotes.pick_random(),
		"correct":rng.randi_range(0, 2),
		"difficulty":difficulty,
		"reward":float(5 + difficulty * 3)
	}

func _next_case() -> void:
	_fill_queue()
	current_case = case_queue.pop_front()
	_fill_queue()
	case_name.text = "%s, %d лет" % [current_case.name, current_case.age]
	case_details.text = "Причина прибытия: %s.\n\nОсобая отметка: %s.\n\nСложность дела: %s" % [current_case.cause, current_case.quirk, "■".repeat(current_case.difficulty)]
	case_quote.text = "«%s»" % current_case.quote
	queue_label.text = "В очереди: %d дел" % case_queue.size()
	progress_label.text = "Обработано за смену: %d" % processed_today

func _decide(choice: int) -> void:
	var correct: bool = choice == int(current_case.correct)
	var reward := float(current_case.reward)
	if correct:
		combo += 1
		var gained: float = reward * (1.0 + float(mini(combo, 10)) * 0.05 + float(int(departments[4].level)) * 0.06)
		souls += gained
		reputation = min(100, reputation + 1)
		if rng.randf() < 0.18:
			stamps += 1
		_log("Дело закрыто правильно: +%.0f душ. Серия: %d." % [gained, combo])
		_show_notice("ВЕРНО  +%.0f" % gained, C_SOUL)
	else:
		combo = 0
		var protection: float = float(int(departments[2].level)) * 0.08
		var penalty: float = maxf(2.0, reward * (0.65 - minf(protection, 0.45)))
		souls = max(0.0, souls - penalty)
		reputation = max(0, reputation - 3)
		_log("Маршрут оспорен комиссией: -%.0f душ." % penalty)
		_show_notice("ОШИБКА  -%.0f" % penalty, C_RED)
	processed_today += 1
	total_processed += 1
	_check_achievements()
	_next_case()
	_refresh_all()
	_save_game()

func _refresh_all() -> void:
	_refresh_header()
	_refresh_departments()
	if queue_label:
		queue_label.text = "В очереди: %d дел" % case_queue.size()
	if progress_label:
		progress_label.text = "Обработано за смену: %d" % processed_today

func _refresh_header() -> void:
	if not souls_label:
		return
	souls_label.text = "ДУШИ\n%s" % _compact(souls)
	rep_label.text = "РЕПУТАЦИЯ\n%d/100" % reputation
	day_label.text = "РАБОЧИЙ ДЕНЬ\n%d" % day
	income_label.text = "АВТОПОТОК\n%s/с" % _compact(_income_per_second())

func _refresh_departments() -> void:
	for child in department_box.get_children():
		child.queue_free()
	for i in departments.size():
		var department: Dictionary = departments[i]
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var name_label := Label.new()
		name_label.text = "%s · ур. %d" % [department.name, department.level]
		name_label.add_theme_font_size_override("font_size", 17)
		name_label.add_theme_color_override("font_color", C_TEXT)
		info.add_child(name_label)
		var description := Label.new()
		description.text = department.description
		description.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		description.add_theme_font_size_override("font_size", 13)
		description.add_theme_color_override("font_color", C_MUTED)
		info.add_child(description)
		row.add_child(info)
		var cost := _department_cost(i)
		var buy := _button("Повысить\n%s" % _compact(cost), C_GOLD)
		buy.custom_minimum_size = Vector2(130, 58)
		buy.disabled = souls < cost
		buy.pressed.connect(_buy_department.bind(i))
		row.add_child(buy)
		department_box.add_child(row)
		if i < departments.size() - 1:
			department_box.add_child(HSeparator.new())

func _buy_department(index: int) -> void:
	var cost := _department_cost(index)
	if souls < cost:
		_show_notice("Недостаточно душ", C_RED)
		return
	souls -= cost
	departments[index].level += 1
	reputation = min(100, reputation + 1)
	_log("%s повышен до уровня %d." % [departments[index].name, departments[index].level])
	_refresh_all()
	_save_game()

func _department_cost(index: int) -> float:
	var department: Dictionary = departments[index]
	return department.base * pow(1.72, department.level)

func _income_per_second() -> float:
	var value := 0.0
	for department in departments:
		value += department.level * department.rate
	if Time.get_unix_time_from_system() < boost_until:
		value *= 2.0
	return value

func _close_day() -> void:
	if processed_today < 8:
		_show_notice("Нужно закрыть ещё %d дел" % (8 - processed_today), C_GOLD)
		return
	var bonus := processed_today * 2.0 + reputation * 0.25
	souls += bonus
	day += 1
	processed_today = 0
	reputation = min(100, reputation + 2)
	_log("День закрыт. Премия за отчётность: +%.0f душ." % bonus)
	_show_notice("ДЕНЬ %d  +%.0f" % [day, bonus], C_GOLD)
	_refresh_all()
	_save_game()

func _rewarded_boost() -> void:
	boost_until = int(Time.get_unix_time_from_system()) + 120
	_log("Получен временный допуск к ускоренной обработке.")
	_show_notice("ДОХОД УДВОЕН НА 2 МИНУТЫ", C_GOLD)
	_refresh_header()
	_save_game()

func _trigger_event() -> void:
	match rng.randi_range(0, 5):
		0:
			var bonus := rng.randi_range(8, 30) + day
			souls += bonus
			_log("Пневмопочта доставила забытый пакет: +%d душ." % bonus)
			_show_notice("СРОЧНАЯ ПОЧТА  +%d" % bonus, C_SOUL)
		1:
			var loss: float = minf(souls, float(rng.randi_range(3, 12)))
			souls -= loss
			_log("Архив потребовал повторную оплату формы: -%.0f душ." % loss)
			_show_notice("АРХИВНЫЙ СБОР  -%.0f" % loss, C_RED)
		2:
			reputation = min(100, reputation + 4)
			_log("Анонимная душа оставила положительный отзыв.")
			_show_notice("РЕПУТАЦИЯ  +4", C_PURPLE)
		3:
			stamps += 1
			_log("Под столом найдена действующая гербовая печать.")
			_show_notice("РЕДКАЯ ПЕЧАТЬ  +1", C_GOLD)
		4:
			var inspector_bonus: int = int(departments[2].level) * 3
			souls += inspector_bonus
			_log("Проверка завершена. Судебный отдел компенсировал %d душ." % inspector_bonus)
			_show_notice("ПРОВЕРКА ЗАВЕРШЕНА", C_GOLD)
		5:
			case_queue.push_front(_generate_case())
			_log("Прибыло срочное дело без сопроводительных документов.")
			_show_notice("СРОЧНОЕ ДЕЛО", C_PURPLE)
	_refresh_all()

func _check_achievements() -> void:
	_unlock("first_case", total_processed >= 1, "Первый не потерялся", 10)
	_unlock("fifty_cases", total_processed >= 50, "Конвейер вечности", 40)
	_unlock("combo_ten", combo >= 10, "Без единой помарки", 30)
	_unlock("trusted", reputation >= 90, "Министерство почти доверяет", 50)
	_unlock("department", departments[0].level >= 10, "Начальник окна №1", 60)

func _unlock(id: String, condition: bool, title: String, reward: int) -> void:
	if condition and not achievements.has(id):
		achievements[id] = {"title":title, "reward":reward}
		souls += reward
		_log("Достижение «%s»: +%d душ." % [title, reward])
		_show_notice("ДОСТИЖЕНИЕ: %s" % title, C_GOLD)

func _show_achievements() -> void:
	if achievements.is_empty():
		_show_notice("Достижений пока нет", C_MUTED)
		return
	var names: Array[String] = []
	for item in achievements.values():
		names.append(item.title)
	_log("Достижения: %s." % ", ".join(names))
	_show_notice("Открыто достижений: %d/5" % achievements.size(), C_PURPLE)

func _show_notice(text_value: String, color: Color) -> void:
	event_label.text = text_value
	event_label.add_theme_color_override("font_color", color)
	var tween := create_tween()
	tween.tween_interval(2.6)
	tween.tween_callback(func():
		event_label.text = "ВНУТРЕННИЙ ЦИРКУЛЯР: соблюдайте спокойствие и нумерацию приложений."
		event_label.add_theme_color_override("font_color", C_GOLD)
	)

func _log(text_value: String) -> void:
	log_lines.push_front("• " + text_value)
	if log_lines.size() > 8:
		log_lines.resize(8)
	if log_label:
		log_label.text = "\n".join(log_lines)

func _compact(value: float) -> String:
	if value >= 1000000:
		return "%.2fM" % (value / 1000000.0)
	if value >= 1000:
		return "%.1fK" % (value / 1000.0)
	return "%.0f" % value

func _save_game() -> void:
	var data := {
		"version": SAVE_VERSION,
		"souls": souls,
		"reputation": reputation,
		"stamps": stamps,
		"day": day,
		"processed_today": processed_today,
		"total_processed": total_processed,
		"departments": departments,
		"achievements": achievements,
		"boost_until": boost_until,
		"saved_at": int(Time.get_unix_time_from_system())
	}
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_var(data)

func _load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var data = file.get_var()
	if typeof(data) != TYPE_DICTIONARY:
		return
	souls = float(data.get("souls", souls))
	reputation = int(data.get("reputation", reputation))
	stamps = int(data.get("stamps", stamps))
	day = int(data.get("day", day))
	processed_today = int(data.get("processed_today", 0))
	total_processed = int(data.get("total_processed", 0))
	var saved_departments = data.get("departments", departments)
	if typeof(saved_departments) == TYPE_ARRAY and saved_departments.size() == departments.size():
		departments = saved_departments
	achievements = data.get("achievements", {})
	boost_until = int(data.get("boost_until", 0))
	var saved_at := int(data.get("saved_at", Time.get_unix_time_from_system()))
	var away := clampi(int(Time.get_unix_time_from_system()) - saved_at, 0, 28800)
	offline_earned = _income_per_second() * away * 0.55
	souls += offline_earned

func _confirm_reset() -> void:
	reset_button.text = "Нажмите ещё раз для сброса"
	if reset_button.has_meta("armed"):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
		get_tree().reload_current_scene()
	else:
		reset_button.set_meta("armed", true)
		var timer := get_tree().create_timer(3.0)
		timer.timeout.connect(func():
			if is_instance_valid(reset_button):
				reset_button.remove_meta("armed")
				reset_button.text = "Новая карьера"
		)

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_WM_CLOSE_REQUEST:
		_save_game()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		get_tree().quit()
