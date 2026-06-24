extends Control

@export var work_minutes: int = 25
var total_seconds: int = 0
var remaining_seconds: int = 0
var is_running: bool = false

# 倒计时数字UI
@onready var time_label: Label = $TimeLabel
@onready var clock_timer: Timer = $ClockTimer
@onready var restart_button: Button = $UI/RestartButton
@onready var start_pause_button: Button = $UI/StartPauseButton

# 时间选项UI控件
@onready var btn_5min: Button = $UI/TimeOptionsPanel/PresetButtons/Btn5min
@onready var btn_15min: Button = $UI/TimeOptionsPanel/PresetButtons/Btn15min
@onready var btn_25min: Button = $UI/TimeOptionsPanel/PresetButtons/Btn25min
@onready var btn_30min: Button = $UI/TimeOptionsPanel/PresetButtons/Btn30min
@onready var btn_45min: Button = $UI/TimeOptionsPanel/PresetButtons/Btn45min
@onready var custom_minutes_input: LineEdit = $UI/TimeOptionsPanel/CustomInput/CustomMinutes
@onready var apply_button: Button = $UI/TimeOptionsPanel/CustomInput/ApplyButton

var current_selected_button: Button = null

# ==================== 【新增】角色动画控制器引用 ====================
# 路径格式：../角色节点名
# 比如主场景里角色实例叫 Character，就写 ../Character
@onready var character: Node3D = get_node_or_null("../qigua")
# ==================================================================

func _ready():
	total_seconds = work_minutes * 60
	remaining_seconds = total_seconds
	is_running = false
	
	# 配置计时器
	clock_timer.wait_time = 1.0
	clock_timer.timeout.connect(_on_timer_tick)
	
	# 绑定按钮信号
	restart_button.pressed.connect(restart_clock)
	start_pause_button.pressed.connect(start_pause_clock)
	
	# 绑定预设时长按钮
	btn_5min.pressed.connect(func(): set_time(5))
	btn_15min.pressed.connect(func(): set_time(15))
	btn_25min.pressed.connect(func(): set_time(25))
	btn_30min.pressed.connect(func(): set_time(30))
	btn_45min.pressed.connect(func(): set_time(45))
	apply_button.pressed.connect(apply_custom_time)
	
	# 输入框数字校验
	custom_minutes_input.text_changed.connect(validate_numeric_input)
	
	# 初始UI状态
	update_time_display()
	start_pause_button.text = "开始"
	highlight_button(btn_25min)

	# ==================== 【新增】初始播放idle动画 ====================
	if character and character.has_method("play_idle"):
		character.play_idle()
	# ==============================================================

func _on_timer_tick():
	if is_running and remaining_seconds > 0:
		remaining_seconds -= 1
		update_time_display()
		
		if remaining_seconds <= 0:
			is_running = false
			time_label.text = "时间到！"
			clock_timer.stop()
			start_pause_button.text = "开始"
			start_pause_button.disabled = false

			# ==================== 【新增】计时结束切回idle ====================
			if character and character.has_method("play_idle"):
				character.play_idle()
			# ==============================================================

func update_time_display():
	var minutes: int = remaining_seconds / 60
	var seconds: int = remaining_seconds % 60
	time_label.text = "%02d:%02d" % [minutes, seconds]

func restart_clock():
	remaining_seconds = total_seconds
	is_running = false
	update_time_display()
	
	if not clock_timer.is_stopped():
		clock_timer.stop()
	
	start_pause_button.text = "开始"
	start_pause_button.disabled = false

	# ==================== 【新增】重置后切回idle ====================
	if character and character.has_method("play_idle"):
		character.play_idle()
	# ==========================================================

func start_pause_clock():
	if remaining_seconds <= 0:
		restart_clock()
		# 重启后直接开始计时
		is_running = true
		clock_timer.start()
		start_pause_button.text = "暂停"
		# ==================== 【新增】开始计时播随机工作动画 ====================
		if character and character.has_method("play_random_work"):
			character.play_random_work()
		# =================================================================
		return
	
	if is_running:
		is_running = false
		clock_timer.stop()
		start_pause_button.text = "开始"
		# ==================== 【新增】暂停切回idle ====================
		if character and character.has_method("play_idle"):
			character.play_idle()
		# ===========================================================
	else:
		is_running = true
		clock_timer.start()
		start_pause_button.text = "暂停"
		# ==================== 【新增】开始播随机工作动画 ====================
		if character and character.has_method("play_random_work"):
			character.play_random_work()
		# ===============================================================

# ========== 时间设置功能 ==========
func set_time(minutes: int):
	minutes = clamp(minutes, 1, 180)
	
	# 如果时间没有变化，不做任何操作
	if minutes == work_minutes and remaining_seconds == total_seconds:
		return
	
	work_minutes = minutes
	total_seconds = work_minutes * 60
	
	var was_running = is_running
	if was_running:
		is_running = false
		clock_timer.stop()
	
	remaining_seconds = total_seconds
	update_time_display()
	
	if was_running:
		is_running = true
		clock_timer.start()
		start_pause_button.text = "暂停"
		# ==================== 【新增】运行中切换时长，重随机动画 ====================
		if character and character.has_method("play_random_work"):
			character.play_random_work()
		# ======================================================================
	else:
		start_pause_button.text = "开始"
		start_pause_button.disabled = false
		# ==================== 【新增】未运行状态保持idle ====================
		if character and character.has_method("play_idle"):
			character.play_idle()
		# ================================================================
	
	highlight_preset_button(minutes)

func apply_custom_time():
	var input_text = custom_minutes_input.text.strip_edges()
	if input_text.is_empty():
		return
	
	# 安全转换为整数
	if not input_text.is_valid_int():
		custom_minutes_input.text = ""
		return
	
	var minutes = input_text.to_int()
	minutes = clamp(minutes, 1, 180)
	set_time(minutes)
	custom_minutes_input.text = str(minutes)

func validate_numeric_input(new_text: String):
	var filtered = ""
	for ch in new_text:
		if ch.is_valid_int():
			filtered += ch
	
	if filtered != new_text:
		custom_minutes_input.text = filtered
		custom_minutes_input.caret_column = filtered.length()

func highlight_preset_button(minutes: int) -> bool:
	var button_map = {
		5: btn_5min,
		15: btn_15min,
		25: btn_25min,
		30: btn_30min,
		45: btn_45min
	}
	if button_map.has(minutes):
		highlight_button(button_map[minutes])
		return true
	else:
		clear_button_highlight()
		return false

func highlight_button(button: Button):
	clear_button_highlight()
	current_selected_button = button
	button.add_theme_color_override("font_color", Color(1, 1, 0))

func clear_button_highlight():
	if current_selected_button and is_instance_valid(current_selected_button):
		current_selected_button.remove_theme_color_override("font_color")
	current_selected_button = null   
