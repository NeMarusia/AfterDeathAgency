extends Control

const BG := Color("08181d")
const PANEL := Color("10282f")
const PANEL_2 := Color("17343c")
const PAPER := Color("eee6cf")
const INK := Color("183037")
const MUTED := Color("9fb3b7")
const GREEN := Color("78d9b0")
const GOLD := Color("e9bd6a")
const RED := Color("e77a78")

var game: AgencyGame
var seals_label: Label
var reputation_label: Label
var shift_label: Label
var timer_label: Label
var progress_label: Label
var case_name: Label
var case_number: Label
var case_cause: Label
var case_summary: Label
var case_stamp: Label
var result_label: Label
var event_label: Label
var passive_label: Label
var department_buttons := {}
var destination_buttons := {}
var report_panel: PanelContainer
var report_text: Label
var next_shift_button: Button
var tutorial_panel: PanelContainer
var achievements_label: Label
var stats_label: Label
var reward_button: Button

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	game = AgencyGame.new()
	add_child(game)
	_build_ui()
	game.changed.connect(_refresh)
	game.case_resolved.connect(_on_case_resolved)
	game.shift_finished.connect(_on_shift_finished)
	game.achievement_unlocked.connect(_on_achievement)
	game.event_started.connect(_on_event)
	game.offline_income_ready.connect(_on_offline_income)
	_refresh()
	if not game.tutorial_complete:
		_show_tutorial()

func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
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

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size = Vector2(270, 0)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)
	left.add_child(_build_shift_panel())
	left.add_child(_build_departments_panel())
	left.add_child(_build_stats_panel())

	var center := VBoxContainer.new()
	center.custom_minimum_size = Vector2(520, 0)
	center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	center.add_theme_constant_override("separation", 12)
	body.add_child(center)
	center.add_child(_build_case_panel())
	center.add_child(_build_destination_panel())

	var right := VBoxContainer.new()
	right.custom_minimum_size = Vector2(270, 0)
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.add_theme_constant_override("separation", 12)
	body.add_child(right)
	right.add_child(_build_event_panel())
	right.add_child(_build_achievements_panel())
	right.add_child(_build_bonus_panel())

	result_label = Label.new()
	result_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	result_label.add_theme_font_size_override("font_size", 17)
	result_label.add_theme_color_override("font_color", Color("dce6e5"))
	root.add_child(result_label)

	_build_report_overlay()
	_build_tutorial_overlay()

func _build_header() -> Control:
	var panel := _panel(PANEL)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 18)
	panel.add_child(row)
	var title := Label.new()
	title.text = "АГЕНТСТВО ПОСТ-СМЕРТНОГО СОПРОВОЖДЕНИЯ"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", GREEN)
	row.add_child(title)
	seals_label = _metric_label()
	reputation_label = _metric_label()
	shift_label = _metric_label()
	row.add_child(seals_label)
	row.add_child(reputation_label)
	row.add_child(shift_label)
	return panel

func _build_shift_panel() -> Control:
	var panel := _panel(PANEL)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_section_title("ТЕКУЩАЯ СМЕНА"))
	timer_label = _body_label()
	progress_label = _body_label()
	passive_label = _body_label()
	box.add_child(timer_label)
	box.add_child(progress_label)
	box.add_child(passive_label)
	return panel

func _build_departments_panel() -> Control:
	var panel := _panel(PANEL)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_section_title("ОТДЕЛЫ"))
	for department in ContentDB.departments():
		var button := Button.new()
		button.custom_minimum_size.y = 54
		button.alignment = HORIZONTAL_ALIGNMENT_LEFT
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.pressed.connect(_buy_department.bind(String(department["id"])))
		_style_button(button, Color(department["accent"]))
		department_buttons[String(department["id"])] = button
		box.add_child(button)
	return panel

func _build_stats_panel() -> Control:
	var panel := _panel(PANEL)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_section_title("АРХИВНЫЕ ДАННЫЕ"))
	stats_label = _body_label()
	stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(stats_label)
	return panel

func _build_case_panel() -> Control:
	var panel := _panel(PAPER, 14)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	var top := HBoxContainer.new()
	box.add_child(top)
	case_number = Label.new()
	case_number.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	case_number.add_theme_color_override("font_color", INK)
	case_number.add_theme_font_size_override("font_size", 15)
	top.add_child(case_number)
	case_stamp = Label.new()
	case_stamp.add_theme_color_override("font_color", RED)
	case_stamp.add_theme_font_size_override("font_size", 16)
	top.add_child(case_stamp)
	case_name = Label.new()
	case_name.add_theme_color_override("font_color", INK)
	case_name.add_theme_font_size_override("font_size", 30)
	case_name.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(case_name)
	box.add_child(_paper_rule())
	var cause_title := _paper_caption("ПРИЧИНА ПРИБЫТИЯ")
	box.add_child(cause_title)
	case_cause = _paper_text(21)
	box.add_child(case_cause)
	box.add_child(_paper_caption("ВЫПИСКА ИЗ ЛИЧНОГО ДЕЛА"))
	case_summary = _paper_text(19)
	case_summary.size_flags_vertical = Control.SIZE_EXPAND_FILL
	case_summary.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	box.add_child(case_summary)
	var note := _paper_text(14)
	note.text = "Форма ПС-13. Решение сотрудника считается окончательным до первой жалобы, проверки или конца света."
	note.modulate = Color(1,1,1,0.68)
	box.add_child(note)
	return panel

func _build_destination_panel() -> Control:
	var panel := _panel(PANEL)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_section_title("ПОСТАВИТЬ МАРШРУТНУЮ ПЕЧАТЬ"))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	box.add_child(row)
	for destination in ContentDB.DESTINATIONS:
		var button := Button.new()
		button.text = String(destination["short"])
		button.custom_minimum_size.y = 62
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.tooltip_text = String(destination["hint"])
		button.pressed.connect(_route_case.bind(String(destination["id"])))
		_style_button(button, Color(destination["color"]))
		destination_buttons[String(destination["id"])] = button
		row.add_child(button)
	return panel

func _build_event_panel() -> Control:
	var panel := _panel(PANEL_2)
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_section_title("ЦИРКУЛЯР ДНЯ"))
	event_label = _body_label()
	event_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	event_label.custom_minimum_size.y = 90
	box.add_child(event_label)
	return panel

func _build_achievements_panel() -> Control:
	var panel := _panel(PANEL)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var box := VBoxContainer.new()
	panel.add_child(box)
	box.add_child(_section_title("ЛИЧНОЕ ДЕЛО СОТРУДНИКА"))
	achievements_label = _body_label()
	achievements_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(achievements_label)
	return panel

func _build_bonus_panel() -> Control:
	var panel := _panel(PANEL)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	panel.add_child(box)
	box.add_child(_section_title("ПРЕМИАЛЬНЫЙ ТАЛОН"))
	var explanation := _body_label()
	explanation.text = "Демонстрация точки монетизации: в релизе здесь может быть добровольная rewarded-реклама. Сейчас награда выдаётся без SDK."
	explanation.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(explanation)
	reward_button = Button.new()
	reward_button.text = "ПОЛУЧИТЬ ПРЕМИЮ"
	reward_button.custom_minimum_size.y = 48
	reward_button.pressed.connect(_claim_reward)
	_style_button(reward_button, GOLD)
	box.add_child(reward_button)
	return panel

func _build_report_overlay() -> void:
	report_panel = _panel(Color("0c2026"), 22)
	report_panel.set_anchors_preset(Control.PRESET_CENTER)
	report_panel.position = Vector2(0,0)
	report_panel.custom_minimum_size = Vector2(520, 360)
	report_panel.visible = false
	report_panel.z_index = 50
	add_child(report_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	report_panel.add_child(box)
	box.add_child(_section_title("ИТОГОВЫЙ ОТЧЁТ СМЕНЫ"))
	report_text = _body_label()
	report_text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	report_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_text.add_theme_font_size_override("font_size", 20)
	report_text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(report_text)
	next_shift_button = Button.new()
	next_shift_button.text = "ПОДПИСАТЬ И НАЧАТЬ НОВУЮ СМЕНУ"
	next_shift_button.custom_minimum_size.y = 58
	next_shift_button.pressed.connect(_next_shift)
	_style_button(next_shift_button, GREEN)
	box.add_child(next_shift_button)

func _build_tutorial_overlay() -> void:
	tutorial_panel = _panel(Color("0c2026"), 22)
	tutorial_panel.set_anchors_preset(Control.PRESET_CENTER)
	tutorial_panel.custom_minimum_size = Vector2(580, 400)
	tutorial_panel.z_index = 60
	tutorial_panel.visible = false
	add_child(tutorial_panel)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 16)
	tutorial_panel.add_child(box)
	box.add_child(_section_title("ВВОДНЫЙ ИНСТРУКТАЖ №0"))
	var text := _body_label()
	text.text = "Перед вами дело умершего. Изучите причину прибытия и выписку, затем отправьте душу в Свет, на Доработку или в Нижнюю канцелярию. Верные решения дают печати и серии. Ошибки портят репутацию. Печати вкладываются в отделы, а Архив продолжает работать даже вне игры.\n\nНикакой морали здесь нет. Есть только регламент, три кнопки и ответственность, которую руководство предусмотрительно делегировало вам."
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.size_flags_vertical = Control.SIZE_EXPAND_FILL
	text.add_theme_font_size_override("font_size", 19)
	box.add_child(text)
	var button := Button.new()
	button.text = "ПРИНЯТЬ ДОЛЖНОСТЬ"
	button.custom_minimum_size.y = 58
	button.pressed.connect(_finish_tutorial)
	_style_button(button, GREEN)
	box.add_child(button)

func _refresh() -> void:
	if not is_instance_valid(game): return
	seals_label.text = "ПЕЧАТИ  %d" % int(floor(game.seals))
	reputation_label.text = "РЕПУТАЦИЯ  %d/100" % game.reputation
	shift_label.text = "СМЕНА  %d" % game.shift_number
	timer_label.text = "До закрытия: %02d:%02d" % [int(game.shift_time_left)/60, int(game.shift_time_left)%60]
	progress_label.text = "Обработано: %d/%d  •  точность: %d%%  •  серия: %d" % [game.shift_processed, game.shift_target, game.accuracy_percent(), game.combo]
	passive_label.text = "Архивный доход: %.1f печ./сек" % game.passive_income_per_second()
	result_label.text = game.last_result_text
	if not game.current_case.is_empty():
		case_number.text = "ДЕЛО №%s  •  %s" % [game.current_case.get("file_number","—"), game.current_case.get("priority","ОБЫЧНОЕ")]
		case_name.text = String(game.current_case.get("name","Неизвестная душа"))
		case_cause.text = String(game.current_case.get("cause","Причина отсутствует"))
		case_summary.text = String(game.current_case.get("summary","Личное дело съедено архивной молью."))
		case_stamp.text = String(game.current_case.get("stamp","ТРЕБУЕТ РЕШЕНИЯ"))
	for department in ContentDB.departments():
		var id := String(department["id"])
		var level := int(game.department_levels[id])
		var cost := game.department_cost(id)
		var button: Button = department_buttons[id]
		button.text = "%s  •  ур. %d\n%s  |  %d печ." % [department["title"], level, department["description"], cost]
		button.disabled = game.seals < cost
	for button in destination_buttons.values():
		button.disabled = not game.shift_active
	stats_label.text = "Всего дел: %d\nОбщая точность: %d%%\nЛучшая серия: %d\nКуплено улучшений: %d" % [game.total_processed, game.total_accuracy_percent(), game.best_combo, game.upgrade_count()]
	achievements_label.text = "Достижения: %d/%d\n\n%s" % [game.completed_achievements(), ContentDB.achievements().size(), _achievement_text()]
	if game.event_title.is_empty(): event_label.text = "Тишина. Вероятно, отдел проверок готовит что-то неприятное."
	else: event_label.text = "%s\n\n%s" % [game.event_title, game.event_description]
	reward_button.disabled = game.rewarded_cooldown > 0.0
	if game.rewarded_cooldown > 0.0: reward_button.text = "ТАЛОН НА СОГЛАСОВАНИИ: %d СЕК." % int(ceil(game.rewarded_cooldown))
	else: reward_button.text = "ПОЛУЧИТЬ ПРЕМИЮ"

func _achievement_text() -> String:
	var lines: Array[String] = []
	for definition in ContentDB.achievements():
		var done := bool(game.achievements.get(String(definition["id"]), false))
		lines.append("%s %s" % ["✓" if done else "○", definition["title"]])
	return "\n".join(lines)

func _route_case(destination_id: String) -> void:
	game.process_case(destination_id)

func _buy_department(id: String) -> void:
	game.buy_department(id)

func _claim_reward() -> void:
	game.claim_demo_rewarded_bonus()

func _on_case_resolved(result: Dictionary) -> void:
	result_label.add_theme_color_override("font_color", GREEN if bool(result.get("correct",false)) else RED)

func _on_shift_finished(report: Dictionary) -> void:
	report_text.text = "Причина закрытия: %s\n\nОценка: %s\nОбработано: %d из %d\nВерно: %d\nОшибки: %d\nТочность: %d%%\nРепутация: %d/100\nПремия: %d печатей" % [report["reason"], report["grade"], report["processed"], report["target"], report["correct"], report["mistakes"], report["accuracy"], report["reputation"], report["bonus"]]
	report_panel.visible = true
	_center_overlay(report_panel)

func _on_achievement(title: String, description: String) -> void:
	result_label.text = "ДОСТИЖЕНИЕ: %s — %s (+25 печатей)" % [title, description]
	result_label.add_theme_color_override("font_color", GOLD)

func _on_event(title: String, description: String) -> void:
	result_label.text = "%s: %s" % [title, description]
	result_label.add_theme_color_override("font_color", GOLD)

func _on_offline_income(amount: int, seconds_away: int) -> void:
	result_label.text = "Архив работал без вас %d мин. Начислено %d печатей." % [seconds_away/60, amount]
	result_label.add_theme_color_override("font_color", GREEN)

func _next_shift() -> void:
	report_panel.visible = false
	game.start_next_shift()

func _show_tutorial() -> void:
	tutorial_panel.visible = true
	_center_overlay(tutorial_panel)

func _finish_tutorial() -> void:
	game.tutorial_complete = true
	game.save_game()
	tutorial_panel.visible = false

func _center_overlay(control: Control) -> void:
	await get_tree().process_frame
	control.position = (size - control.size) * 0.5

func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		if report_panel and report_panel.visible: _center_overlay(report_panel)
		if tutorial_panel and tutorial_panel.visible: _center_overlay(tutorial_panel)

func _panel(color: Color, radius := 10) -> PanelContainer:
	var panel := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.corner_radius_top_left = radius
	style.corner_radius_top_right = radius
	style.corner_radius_bottom_left = radius
	style.corner_radius_bottom_right = radius
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	style.border_width_left = 1
	style.border_width_right = 1
	style.border_width_top = 1
	style.border_width_bottom = 1
	style.border_color = Color(1,1,1,0.08)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _style_button(button: Button, accent: Color) -> void:
	button.add_theme_font_size_override("font_size", 15)
	button.add_theme_color_override("font_color", Color("e8f0ef"))
	button.add_theme_color_override("font_hover_color", Color.WHITE)
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color(accent, 0.13)
	normal.border_color = Color(accent, 0.55)
	normal.set_border_width_all(1)
	normal.set_corner_radius_all(7)
	normal.set_content_margin_all(10)
	var hover := normal.duplicate()
	hover.bg_color = Color(accent, 0.24)
	var pressed := normal.duplicate()
	pressed.bg_color = Color(accent, 0.34)
	var disabled := normal.duplicate()
	disabled.bg_color = Color(0.1,0.14,0.15,0.65)
	disabled.border_color = Color(0.5,0.55,0.56,0.18)
	button.add_theme_stylebox_override("normal", normal)
	button.add_theme_stylebox_override("hover", hover)
	button.add_theme_stylebox_override("pressed", pressed)
	button.add_theme_stylebox_override("disabled", disabled)

func _section_title(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", GOLD)
	return label

func _metric_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", Color("dce6e5"))
	return label

func _body_label() -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", 16)
	label.add_theme_color_override("font_color", MUTED)
	return label

func _paper_caption(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	label.add_theme_color_override("font_color", Color(INK,0.65))
	return label

func _paper_text(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", INK)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label

func _paper_rule() -> HSeparator:
	var rule := HSeparator.new()
	rule.modulate = Color(INK,0.25)
	return rule
