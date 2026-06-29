extends Control

@export var dialog_label: Label
@export var tomato_timer: Node
@export var time_label: Label

# ✅ 新增：Typewriter 引用
@export var typewriter: Typewriter

@export var idle_dialog_texts: Array[String] = [
	"休息一下眼睛吧",
	"休息也不要刷手机哦",
	"劳逸逸逸逸逸逸逸逸结合",
	"多喝水有助于你的记忆",
	"坐久了站起来活动活动",
	"加油，专注的你超棒的",
	"你今天学习了吗（",
	"我从不丢掉我的发射（歌唱"
]

@export var work_dialog_texts: Array[String] = [
	"看看几点了还走神",
	"当你看见这句话的时候你已经走神了",
	"好好学习天天向上",
	"你也不想你摸鱼的事情被传出去吧（邪恶",
	"好好学习一会奖励自己吃好吃的",
	"你要是走神我就要问问你中药药效了，那我问你",
	"不学习就回家吧！回家吧！"
]

@export var pet_dialog_texts: Array[String] = [
	"有点晕（",
	"东西背完了吗就摸我头",
	"摸够了就去学习！",
	"诶呀诶呀诶呀！！"
]

@export var interval_min: float = 1.0
@export var interval_max: float = 2.0
@export var display_time: float = 2.5
@export var check_interval: float = 0.3
@export var pet_display_time: float = 2.5

# ✅ 角色状态管理（不再依赖外部节点）
enum CharacterState {
	IDLE,
	WORK,
	PET
}

var _current_state: CharacterState = CharacterState.IDLE
var _is_timing: bool = false  # 番茄钟是否在计时
var _is_petting: bool = false  # 是否在抚摸

var _dialog_timer: Timer
var _check_timer: Timer
var _signals_connected: bool = false
var _current_hide_timer: Timer = null

func _ready():
	if not dialog_label:
		print("❌ 错误：dialog_label 未绑定")
		return
	
	# ✅ 自动查找 Typewriter
	if not typewriter:
		typewriter = get_node_or_null("Typewriter")
		if typewriter:
			typewriter.typing_finished.connect(_on_typing_finished)
			print("✅ Typewriter 已连接")
		else:
			print("⚠️ 未找到 Typewriter 节点，将使用普通显示模式")
	
	dialog_label.visible = false
	
	if time_label:
		print("✅ time_label 已绑定：", time_label.name)
	else:
		print("⚠️ time_label 未绑定，尝试自动查找...")
		if tomato_timer:
			time_label = _find_time_label(tomato_timer)
			if time_label:
				print("✅ 自动找到 TimeLabel：", time_label.name)
			else:
				print("❌ 找不到 TimeLabel")
	
	if time_label:
		_update_time_display()
		print("⏰ 初始时间已设置：", time_label.text)
	
	_dialog_timer = Timer.new()
	_dialog_timer.one_shot = true
	_dialog_timer.timeout.connect(_on_dialog_timer_timeout)
	add_child(_dialog_timer)
	
	_check_timer = Timer.new()
	_check_timer.wait_time = check_interval
	_check_timer.timeout.connect(_check_tomato_state)
	add_child(_check_timer)
	_check_timer.start()
	
	if not tomato_timer:
		tomato_timer = get_node_or_null("../Clock")
		if not tomato_timer:
			tomato_timer = get_node_or_null("../../Clock")
		if not tomato_timer:
			tomato_timer = get_node_or_null("/root/Main/Clock")
	
	if tomato_timer:
		print("✅ 番茄钟绑定成功：", tomato_timer.name)
	else:
		print("⚠️ 未找到番茄钟")
	
	_connect_signals()
	_start_dialog_cycle()
	print("✅ 对话系统已启动")

func _find_time_label(node: Node) -> Label:
	for child in node.get_children():
		if child is Label and child.name == "TimeLabel":
			return child
		var found = _find_time_label(child)
		if found:
			return found
	return null

func _update_time_display():
	if not time_label:
		return
	
	if not tomato_timer:
		return
	
	if "time_left" in tomato_timer:
		var time_left = tomato_timer.get("time_left")
		if time_left != null and time_left > 0:
			var seconds = int(time_left)
			var minutes = seconds / 60
			var secs = seconds % 60
			time_label.text = "%02d:%02d" % [minutes, secs]
		else:
			time_label.text = "00:00"
	else:
		time_label.text = "--:--"

func _connect_signals():
	if _signals_connected:
		return
	
	if SignalBus.instance:
		SignalBus.instance.petting_started.connect(_on_petting_started)
		SignalBus.instance.petting_ended.connect(_on_petting_ended)
		SignalBus.instance.pet_dialog_triggered.connect(_on_pet_dialog_triggered)
		SignalBus.instance.anim_play_idle.connect(_on_state_changed_idle)
		SignalBus.instance.anim_play_work.connect(_on_state_changed_work)
		_signals_connected = true
		print("✅ 已连接到信号总线")
	else:
		print("⚠️ SignalBus 未找到")

# ========== ✅ 角色状态切换回调 ==========
func _on_state_changed_idle():
	_set_state(CharacterState.IDLE)
	print("🔄 角色状态：待机")

func _on_state_changed_work():
	_set_state(CharacterState.WORK)
	print("🔄 角色状态：工作中")

func _set_state(new_state: CharacterState):
	if _current_state == new_state:
		return
	
	_current_state = new_state
	
	# ✅ 如果正在打字或抚摸，不立即切换对话
	if _is_petting or (typewriter and typewriter.is_typing()):
		print("⏸️ 打字或抚摸中，延迟切换对话")
		return
	
	# 切换状态时刷新对话
	_stop_dialog()
	_show_next_dialog()
	_start_dialog_cycle()

func _on_dialog_timer_timeout():
	_show_next_dialog()

func _start_dialog_cycle() -> void:
	if not is_instance_valid(_dialog_timer) or not is_inside_tree():
		return
	_dialog_timer.stop()
	
	# ✅ 如果正在抚摸或正在打字，不启动普通对话循环
	if _is_petting or (typewriter and typewriter.is_typing()):
		print("⏸️ 抚摸中或打字中，暂停普通对话循环")
		return
	
	var interval = randf_range(interval_min, interval_max)
	_dialog_timer.wait_time = interval
	_dialog_timer.start()

func _stop_dialog() -> void:
	if is_instance_valid(_dialog_timer):
		_dialog_timer.stop()
	
	if typewriter and typewriter.is_typing():
		typewriter.stop()
	
	if dialog_label:
		dialog_label.visible = false
		dialog_label.text = ""
	
	if _current_hide_timer and is_instance_valid(_current_hide_timer):
		_current_hide_timer.queue_free()
		_current_hide_timer = null

func _on_typing_finished():
	print("✅ 打字完成")
	_start_hide_timer(display_time, "_on_dialog_hide_timeout")

func _start_hide_timer(wait_time: float, callback: String) -> void:
	if _current_hide_timer and is_instance_valid(_current_hide_timer):
		_current_hide_timer.queue_free()
		_current_hide_timer = null
	
	_current_hide_timer = Timer.new()
	_current_hide_timer.one_shot = true
	_current_hide_timer.wait_time = wait_time
	_current_hide_timer.timeout.connect(Callable(self, callback))
	add_child(_current_hide_timer)
	_current_hide_timer.start()

func _show_dialog_text(text: String) -> void:
	if not dialog_label:
		return
	
	if typewriter:
		if typewriter.is_typing():
			typewriter.stop()
		
		dialog_label.visible = true
		typewriter.type_text(text)
	else:
		dialog_label.text = text
		dialog_label.visible = true
		_start_hide_timer(display_time, "_on_dialog_hide_timeout")

# ========== ✅ 根据当前状态获取对话列表 ==========
func _get_dialog_list_by_state() -> Array[String]:
	if _current_state == CharacterState.WORK:
		return work_dialog_texts
	elif _current_state == CharacterState.PET:
		return pet_dialog_texts
	else:
		return idle_dialog_texts

func _show_next_dialog() -> void:
	if not dialog_label:
		return
	
	if _is_petting or (typewriter and typewriter.is_typing()):
		print("⏭️ 抚摸中或打字中，跳过普通对话")
		_start_dialog_cycle()
		return
	
	if _current_state == CharacterState.PET:
		_start_dialog_cycle()
		return
	
	var text_list = _get_dialog_list_by_state()
	if text_list.is_empty():
		return
	
	var text = text_list[randi() % text_list.size()]
	_show_dialog_text(text)

func _on_dialog_hide_timeout() -> void:
	if is_instance_valid(dialog_label):
		dialog_label.visible = false
		dialog_label.text = ""
	
	if _current_hide_timer and is_instance_valid(_current_hide_timer):
		_current_hide_timer.queue_free()
		_current_hide_timer = null
	
	_start_dialog_cycle()

# ========== 抚摸相关 ==========
func _on_petting_started():
	_is_petting = true
	_set_state(CharacterState.PET)
	_stop_dialog()
	_show_pet_dialog()
	print("🐱 抚摸触发对话")

func _on_petting_ended():
	_is_petting = false
	# ✅ 抚摸结束后，根据番茄钟状态恢复状态
	if _is_timing:
		_set_state(CharacterState.WORK)
	else:
		_set_state(CharacterState.IDLE)
	print("🐱 抚摸结束，恢复普通对话")

func _on_pet_dialog_triggered(message: String):
	if message != "":
		_show_specific_dialog(message)
	else:
		_show_pet_dialog()

func _show_pet_dialog() -> void:
	if not dialog_label or pet_dialog_texts.is_empty():
		return
	
	if typewriter and typewriter.is_typing():
		typewriter.stop()
	
	var text = pet_dialog_texts[randi() % pet_dialog_texts.size()]
	_show_dialog_text(text)

func _show_specific_dialog(message: String):
	if not dialog_label:
		return
	
	_stop_dialog()
	_show_dialog_text(message)

func _on_pet_dialog_hide_timeout() -> void:
	if is_instance_valid(dialog_label):
		dialog_label.visible = false
		dialog_label.text = ""
	
	if _current_hide_timer and is_instance_valid(_current_hide_timer):
		_current_hide_timer.queue_free()
		_current_hide_timer = null
	
	if _is_petting:
		print("🐱 继续显示下一条抚摸对话")
		_show_pet_dialog()
	else:
		_start_dialog_cycle()

# ========== 番茄钟状态 ==========
func _check_tomato_state() -> void:
	if not tomato_timer:
		return
	if not "is_running" in tomato_timer:
		return
	
	var now_timing = tomato_timer.get("is_running")
	if now_timing == null:
		now_timing = false
	
	if now_timing != _is_timing:
		_is_timing = now_timing
		print("🔄 番茄钟切换 -> ", "计时中" if _is_timing else "待机")
		
		_update_time_display()
		
		if _is_petting or (typewriter and typewriter.is_typing()):
			print("⏸️ 抚摸中或打字中，不切换状态")
			return
		
		# ✅ 根据番茄钟状态切换角色状态
		if _is_timing:
			_set_state(CharacterState.WORK)
		else:
			_set_state(CharacterState.IDLE)

# ========== ✅ 公共方法：外部可以调用切换状态 ==========
func switch_to_idle():
	_set_state(CharacterState.IDLE)

func switch_to_work():
	_set_state(CharacterState.WORK)

func switch_to_pet():
	_set_state(CharacterState.PET)
