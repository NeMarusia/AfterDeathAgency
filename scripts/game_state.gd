class_name AgencyGame
extends Node

signal changed
signal case_resolved(result: Dictionary)
signal shift_finished(report: Dictionary)
signal achievement_unlocked(title: String, description: String)
signal event_started(title: String, description: String)
signal offline_income_ready(amount: int, seconds_away: int)

const SAVE_PATH := "user://agency_save_v2.json"
const SAVE_VERSION := 2
const SHIFT_DURATION := 82.0
const MAX_OFFLINE_SECONDS := 8 * 60 * 60

var rng := RandomNumberGenerator.new()
var case_pool: Array = []
var departments: Array = []
var achievement_defs: Array = []
var seals: float = 35.0
var reputation: int = 50
var shift_number: int = 1
var shift_time_left: float = SHIFT_DURATION
var shift_active: bool = true
var shift_target: int = 10
var shift_processed: int = 0
var shift_correct: int = 0
var shift_mistakes: int = 0
var total_processed: int = 0
var total_correct: int = 0
var total_seals_earned: float = 0.0
var combo: int = 0
var best_combo: int = 0
var current_case: Dictionary = {}
var last_case_index: int = -1
var department_levels := {"archive":0,"training":0,"audit":0,"reception":0}
var achievements := {}
var tutorial_complete := false
var reduced_motion := false
var event_title := ""
var event_description := ""
var reward_multiplier := 1.0
var temporary_penalty_reduction := 0
var next_reward_multiplier := 1.0
var event_elapsed := 0.0
var next_event_at := 22.0
var passive_accumulator := 0.0
var autosave_accumulator := 0.0
var rewarded_cooldown := 0.0
var last_saved_unix := 0
var last_result_text := "Смена началась. Канцелярия делает вид, что всё под контролем."

func _ready() -> void:
	rng.randomize()
	case_pool = ContentDB.cases()
	departments = ContentDB.departments()
	achievement_defs = ContentDB.achievements()
	load_game()
	if current_case.is_empty(): generate_case()
	changed.emit()

func _process(delta: float) -> void:
	if rewarded_cooldown > 0.0: rewarded_cooldown = maxf(0.0, rewarded_cooldown - delta)
	if not shift_active:
		autosave_accumulator += delta
		if autosave_accumulator >= 5.0:
			autosave_accumulator = 0.0
			save_game()
		return
	shift_time_left = maxf(0.0, shift_time_left - delta)
	passive_accumulator += delta
	event_elapsed += delta
	autosave_accumulator += delta
	if passive_accumulator >= 1.0:
		var ticks := int(passive_accumulator)
		passive_accumulator -= float(ticks)
		var passive_gain := passive_income_per_second() * float(ticks)
		if passive_gain > 0.0:
			seals += passive_gain
			total_seals_earned += passive_gain
			changed.emit()
	if event_elapsed >= next_event_at:
		event_elapsed = 0.0
		next_event_at = rng.randf_range(24.0, 36.0)
		trigger_random_event()
	if autosave_accumulator >= 5.0:
		autosave_accumulator = 0.0
		save_game()
	if shift_time_left <= 0.0: finish_shift("Время смены истекло")
	else: changed.emit()

func generate_case() -> void:
	if case_pool.is_empty(): return
	var index := rng.randi_range(0, case_pool.size() - 1)
	if case_pool.size() > 1 and index == last_case_index: index = (index + 1) % case_pool.size()
	last_case_index = index
	current_case = case_pool[index].duplicate(true)
	current_case["file_number"] = "%02d-%04d/%d" % [shift_number, rng.randi_range(1000,9999), rng.randi_range(1,9)]
	current_case["priority"] = ["ОБЫЧНОЕ","СРОЧНОЕ","СОВЕРШЕННО ОБЫЧНОЕ"][rng.randi_range(0,2)]
	changed.emit()

func process_case(destination_id: String) -> Dictionary:
	if not shift_active or current_case.is_empty(): return {}
	var is_correct := destination_id == String(current_case.get("target","recycle"))
	var base_reward := float(current_case.get("value",10)) + float(department_levels["reception"] * 2)
	var combo_bonus := 1.0 + minf(float(combo),10.0) * (0.03 + float(department_levels["training"]) * 0.01)
	var earned := 0
	var penalty := 0
	shift_processed += 1
	total_processed += 1
	if is_correct:
		combo += 1
		best_combo = maxi(best_combo, combo)
		shift_correct += 1
		total_correct += 1
		earned = int(round(base_reward * combo_bonus * reward_multiplier * next_reward_multiplier))
		next_reward_multiplier = 1.0
		seals += float(earned)
		total_seals_earned += float(earned)
		reputation = mini(100, reputation + 1 + int(combo >= 7))
		last_result_text = "Маршрут подтверждён. +%d печатей, серия: %d." % [earned,combo]
	else:
		combo = 0
		shift_mistakes += 1
		var base_penalty := 7 + shift_number
		penalty = maxi(1, base_penalty - department_levels["audit"] * 2 - temporary_penalty_reduction)
		reputation = maxi(0, reputation - penalty)
		seals = maxf(0.0, seals - float(penalty * 2))
		var correct_destination := ContentDB.destination_by_id(String(current_case.get("target","recycle")))
		last_result_text = "Ошибка маршрутизации. Правильно: %s. Репутация −%d." % [correct_destination["short"],penalty]
	var result := {"correct":is_correct,"earned":earned,"penalty":penalty,"text":last_result_text,"case":current_case.duplicate(true)}
	case_resolved.emit(result)
	check_achievements()
	if reputation <= 0: finish_shift("Лицензия временно приостановлена")
	elif shift_processed >= shift_target: finish_shift("План смены выполнен")
	else:
		generate_case()
		save_game()
	changed.emit()
	return result

func department_cost(department_id: String) -> int:
	var definition := get_department(department_id)
	if definition.is_empty(): return 999999
	var level := int(department_levels.get(department_id,0))
	return int(round(float(definition["base_cost"]) * pow(1.72,level)))

func buy_department(department_id: String) -> bool:
	var cost := department_cost(department_id)
	if seals < float(cost):
		last_result_text = "Казначейство отказало: не хватает %d печатей." % int(ceil(float(cost)-seals))
		changed.emit()
		return false
	seals -= float(cost)
	department_levels[department_id] = int(department_levels.get(department_id,0)) + 1
	last_result_text = "%s повышен до уровня %d." % [get_department(department_id)["title"],department_levels[department_id]]
	check_achievements()
	save_game()
	changed.emit()
	return true

func get_department(department_id: String) -> Dictionary:
	for department in departments:
		if String(department["id"]) == department_id: return department
	return {}

func passive_income_per_second() -> float:
	var level := int(department_levels["archive"])
	if level <= 0: return 0.0
	return 0.45 * float(level) * (1.0 + float(shift_number-1) * 0.04)

func accuracy_percent() -> int:
	if shift_processed <= 0: return 100
	return int(round(float(shift_correct) / float(shift_processed) * 100.0))

func total_accuracy_percent() -> int:
	if total_processed <= 0: return 100
	return int(round(float(total_correct) / float(total_processed) * 100.0))

func upgrade_count() -> int:
	var total := 0
	for value in department_levels.values(): total += int(value)
	return total

func finish_shift(reason: String) -> void:
	if not shift_active: return
	shift_active = false
	var target_met := shift_processed >= shift_target
	var accuracy := accuracy_percent()
	var grade := "C"
	if target_met and accuracy >= 90: grade = "A"
	elif target_met and accuracy >= 75: grade = "B"
	elif accuracy < 55: grade = "D"
	var performance_bonus := 0
	if grade == "A": performance_bonus = 60 + shift_number * 8
	elif grade == "B": performance_bonus = 30 + shift_number * 5
	elif grade == "C": performance_bonus = 12
	seals += float(performance_bonus)
	total_seals_earned += float(performance_bonus)
	var report := {"reason":reason,"grade":grade,"processed":shift_processed,"correct":shift_correct,"mistakes":shift_mistakes,"accuracy":accuracy,"target":shift_target,"bonus":performance_bonus,"reputation":reputation}
	last_result_text = "%s. Отчёт сформирован автоматически, что уже подозрительно." % reason
	check_achievements()
	save_game()
	shift_finished.emit(report)
	changed.emit()

func start_next_shift() -> void:
	shift_number += 1
	shift_target = 9 + shift_number * 2
	shift_time_left = SHIFT_DURATION + minf(float(shift_number-1)*2.0,18.0)
	shift_processed = 0
	shift_correct = 0
	shift_mistakes = 0
	combo = 0
	shift_active = true
	reward_multiplier = 1.0
	temporary_penalty_reduction = 0
	next_reward_multiplier = 1.0
	event_title = ""
	event_description = ""
	event_elapsed = 0.0
	next_event_at = rng.randf_range(18.0,28.0)
	reputation = mini(100,reputation+8)
	last_result_text = "Смена №%d открыта. Новые формы уже устарели." % shift_number
	generate_case()
	save_game()
	changed.emit()

func trigger_random_event() -> void:
	var events := ContentDB.events()
	if events.is_empty(): return
	var event: Dictionary = events[rng.randi_range(0,events.size()-1)]
	event_title = String(event["title"])
	event_description = String(event["description"])
	match String(event["kind"]):
		"reward": reward_multiplier = maxf(reward_multiplier,float(event["amount"]))
		"penalty": temporary_penalty_reduction += int(event["amount"])
		"instant":
			seals += float(event["amount"])
			total_seals_earned += float(event["amount"])
		"time": shift_time_left += float(event["amount"])
		"next_double": next_reward_multiplier = float(event["amount"])
	last_result_text = "%s: %s" % [event_title,event_description]
	event_started.emit(event_title,event_description)
	save_game()
	changed.emit()

func claim_demo_rewarded_bonus() -> bool:
	if rewarded_cooldown > 0.0:
		last_result_text = "Премиальный талон ещё согласовывается: %d сек." % int(ceil(rewarded_cooldown))
		changed.emit()
		return false
	rewarded_cooldown = 90.0
	var bonus := 45 + shift_number * 5
	seals += float(bonus)
	total_seals_earned += float(bonus)
	next_reward_multiplier = maxf(next_reward_multiplier,1.5)
	last_result_text = "Демонстрационная премия начислена: +%d печатей и усилено следующее дело." % bonus
	save_game()
	changed.emit()
	return true

func check_achievements() -> void:
	_try_unlock("first_case",total_correct>=1)
	_try_unlock("combo_5",best_combo>=5)
	_try_unlock("combo_10",best_combo>=10)
	_try_unlock("upgrade_5",upgrade_count()>=5)
	_try_unlock("shift_3",shift_number>=3 and not shift_active)
	_try_unlock("hundred_cases",total_processed>=100)

func _try_unlock(id: String, condition: bool) -> void:
	if not condition or bool(achievements.get(id,false)): return
	achievements[id] = true
	for definition in achievement_defs:
		if String(definition["id"]) == id:
			achievement_unlocked.emit(String(definition["title"]),String(definition["description"]))
			seals += 25.0
			total_seals_earned += 25.0
			break

func completed_achievements() -> int:
	var count := 0
	for value in achievements.values():
		if bool(value): count += 1
	return count

func save_game() -> void:
	last_saved_unix = int(Time.get_unix_time_from_system())
	var data := {"version":SAVE_VERSION,"seals":seals,"reputation":reputation,"shift_number":shift_number,"shift_time_left":shift_time_left,"shift_active":shift_active,"shift_target":shift_target,"shift_processed":shift_processed,"shift_correct":shift_correct,"shift_mistakes":shift_mistakes,"total_processed":total_processed,"total_correct":total_correct,"total_seals_earned":total_seals_earned,"combo":combo,"best_combo":best_combo,"current_case":current_case,"department_levels":department_levels,"achievements":achievements,"tutorial_complete":tutorial_complete,"reduced_motion":reduced_motion,"rewarded_cooldown":rewarded_cooldown,"last_saved_unix":last_saved_unix}
	var file := FileAccess.open(SAVE_PATH,FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		last_saved_unix = int(Time.get_unix_time_from_system())
		return
	var file := FileAccess.open(SAVE_PATH,FileAccess.READ)
	if not file: return
	var parsed = JSON.parse_string(file.get_as_text())
	file.close()
	if not parsed is Dictionary: return
	var data: Dictionary = parsed
	seals = float(data.get("seals",seals)); reputation = int(data.get("reputation",reputation)); shift_number = int(data.get("shift_number",shift_number)); shift_time_left = float(data.get("shift_time_left",shift_time_left)); shift_active = bool(data.get("shift_active",shift_active)); shift_target = int(data.get("shift_target",shift_target)); shift_processed = int(data.get("shift_processed",shift_processed)); shift_correct = int(data.get("shift_correct",shift_correct)); shift_mistakes = int(data.get("shift_mistakes",shift_mistakes)); total_processed = int(data.get("total_processed",total_processed)); total_correct = int(data.get("total_correct",total_correct)); total_seals_earned = float(data.get("total_seals_earned",total_seals_earned)); combo = int(data.get("combo",combo)); best_combo = int(data.get("best_combo",best_combo)); current_case = data.get("current_case",current_case)
	var loaded_levels = data.get("department_levels",department_levels)
	if loaded_levels is Dictionary:
		for key in department_levels.keys(): department_levels[key] = int(loaded_levels.get(key,department_levels[key]))
	var loaded_achievements = data.get("achievements",{})
	if loaded_achievements is Dictionary: achievements = loaded_achievements
	tutorial_complete = bool(data.get("tutorial_complete",false)); reduced_motion = bool(data.get("reduced_motion",false)); rewarded_cooldown = float(data.get("rewarded_cooldown",0.0))
	var previous_saved := int(data.get("last_saved_unix",int(Time.get_unix_time_from_system())))
	last_saved_unix = int(Time.get_unix_time_from_system())
	var away_seconds := clampi(last_saved_unix-previous_saved,0,MAX_OFFLINE_SECONDS)
	if away_seconds >= 30:
		var offline_amount := int(floor(passive_income_per_second()*float(away_seconds)*0.55))
		if offline_amount > 0:
			seals += float(offline_amount)
			total_seals_earned += float(offline_amount)
			call_deferred("_emit_offline_income",offline_amount,away_seconds)

func _emit_offline_income(amount: int, seconds_away: int) -> void: offline_income_ready.emit(amount,seconds_away)

func reset_progress() -> void:
	seals=35.0; reputation=50; shift_number=1; shift_time_left=SHIFT_DURATION; shift_active=true; shift_target=10; shift_processed=0; shift_correct=0; shift_mistakes=0; total_processed=0; total_correct=0; total_seals_earned=0.0; combo=0; best_combo=0; current_case={}; department_levels={"archive":0,"training":0,"audit":0,"reception":0}; achievements={}; tutorial_complete=false; rewarded_cooldown=0.0
	last_result_text = "Личное дело уничтожено. Комиссия уверяет, что это штатная процедура."
	generate_case(); save_game(); changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT or what == NOTIFICATION_WM_CLOSE_REQUEST: save_game()
