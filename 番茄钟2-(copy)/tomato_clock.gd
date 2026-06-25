extends Node

# ========== 信号 ==========
signal time_updated(time_string: String)
signal timer_finished()
signal state_changed(is_running: bool)

# ========== 导出变量 ==========
@export var default_minutes: int = 25
@export var time_label: Label

# ========== 按钮引用 ==========
@export var start_pause_button: Button
@export var restart_button: Button
@export var btn_5min: Button
@export var btn_15min: Button
@export var btn_25min: Button
@export var btn_30min: Button
@export var btn_45min: Button
@export var apply_button: Button
@export var custom_minute_input: LineEdit

# ========== 私有变量 ==========
var _time_left: float = 0.0
var _is_running: bool = false
var _is_paused: bool = false
var _timer: Timer

# ========== 属性访问器 ==========
var time_left: float:
	get: return _time_left

var is_running: bool:
	get: return _is_running

# ========== 初始化 ==========
func _ready():
	_timer = Timer.new()
	_timer.wait_time = 0.1
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	
	set_time(default_minutes)
	_update_display()
	
	_connect_buttons()
	
	# 初始状态：待机
	if SignalBus.instance:
		SignalBus.instance.anim_play_idle.emit()
		print("🎬 初始：发送待机信号")
	
	print("✅ TomatoClock 初始化完成，默认时间：", default_minutes, " 分钟")

# ========== 连接按钮信号 ==========
func _connect_buttons():
	if start_pause_button:
		start_pause_button.pressed.connect(_on_start_pause_pressed)
		print("✅ 开始/暂停按钮已连接")
	
	if restart_button:
		restart_button.pressed.connect(_on_restart_pressed)
		print("✅ 重置按钮已连接")
	
	if btn_5min:
		btn_5min.pressed.connect(func(): set_time(5); _update_display())
		print("✅ 5分钟按钮已连接")
	if btn_15min:
		btn_15min.pressed.connect(func(): set_time(15); _update_display())
		print("✅ 15分钟按钮已连接")
	if btn_25min:
		btn_25min.pressed.connect(func(): set_time(25); _update_display())
		print("✅ 25分钟按钮已连接")
	if btn_30min:
		btn_30min.pressed.connect(func(): set_time(30); _update_display())
		print("✅ 30分钟按钮已连接")
	if btn_45min:
		btn_45min.pressed.connect(func(): set_time(45); _update_display())
		print("✅ 45分钟按钮已连接")
	
	if apply_button and custom_minute_input:
		apply_button.pressed.connect(_on_apply_pressed)
		print("✅ 自定义时间按钮已连接")

# ========== 按钮回调 ==========
func _on_start_pause_pressed():
	print("🔄 开始/暂停按钮被点击")
	if _is_running and not _is_paused:
		# 正在运行 → 暂停
		pause()
		if start_pause_button:
			start_pause_button.text = "继续"
	elif _is_running and _is_paused:
		# 暂停中 → 继续
		resume()
		if start_pause_button:
			start_pause_button.text = "暂停"
	else:
		# 未开始 → 开始
		start()
		if start_pause_button:
			start_pause_button.text = "暂停"

func _on_restart_pressed():
	print("🔄 重置按钮被点击")
	reset()
	if start_pause_button:
		start_pause_button.text = "开始"

func _on_apply_pressed():
	if custom_minute_input:
		var text = custom_minute_input.text
		var minutes = int(text)
		if minutes > 0:
			set_time(minutes)
			_update_display()
			if start_pause_button:
				start_pause_button.text = "开始"
			print("✅ 自定义时间已设置：", minutes, " 分钟")

# ========== 核心功能 ==========

func set_time(minutes: int):
	_time_left = float(minutes * 60)
	_update_display()
	if start_pause_button:
		start_pause_button.text = "开始"
	print("⏰ 设置时间：", minutes, " 分钟")

func start():
	print("▶️ start() 被调用")
	if _time_left <= 0:
		print("⚠️ 时间已归零，请先设置时间")
		return
	
	_is_running = true
	_is_paused = false
	_timer.start()
	state_changed.emit(true)
	
	# 切换到工作动画
	if SignalBus.instance:
		SignalBus.instance.anim_play_work.emit()
		print("🎬 发送工作动画信号")
	
	print("▶️ 计时开始")

func pause():
	if not _is_running:
		return
	
	_is_paused = true
	_timer.stop()
	
	# ✅ 暂停时切换到待机动画
	if SignalBus.instance:
		SignalBus.instance.anim_play_idle.emit()
		print("🎬 暂停：切换到待机动画")
	
	print("⏸️ 计时暂停")

func resume():
	if not _is_running or not _is_paused:
		return
	
	_is_paused = false
	_timer.start()
	
	# ✅ 继续时切换到工作动画
	if SignalBus.instance:
		SignalBus.instance.anim_play_work.emit()
		print("🎬 继续：切换到工作动画")
	
	print("▶️ 计时继续")

func stop():
	print("⏹️ stop() 被调用")
	_is_running = false
	_is_paused = false
	_timer.stop()
	state_changed.emit(false)
	if start_pause_button:
		start_pause_button.text = "开始"
	
	# 回到待机动画
	if SignalBus.instance:
		SignalBus.instance.anim_play_idle.emit()
		print("🎬 发送待机信号")
	
	print("⏹️ 计时停止")

func reset():
	print("🔄 reset() 被调用")
	stop()
	set_time(default_minutes)
	_update_display()
	if start_pause_button:
		start_pause_button.text = "开始"
	
	if SignalBus.instance:
		SignalBus.instance.anim_play_idle.emit()
	
	print("🔄 计时重置")

# ========== 私有方法 ==========

func _on_timer_timeout():
	if not _is_running or _is_paused:
		return
	
	_time_left -= 0.1
	
	if _time_left <= 0:
		_time_left = 0
		_update_display()
		_timer.stop()
		_is_running = false
		state_changed.emit(false)
		timer_finished.emit()
		if start_pause_button:
			start_pause_button.text = "开始"
		
		if SignalBus.instance:
			SignalBus.instance.anim_play_idle.emit()
			print("🎬 计时结束，发送待机信号")
		
		print("🔔 计时结束！")
		return
	
	if int(_time_left) != int(_time_left + 0.1):
		_update_display()

func _update_display():
	if not time_label:
		return
	
	var seconds = int(_time_left)
	var minutes = seconds / 60
	var secs = seconds % 60
	var time_string = "%02d:%02d" % [minutes, secs]
	
	time_label.text = time_string
	time_updated.emit(time_string)

# ========== 公共方法 ==========

func get_time_string() -> String:
	var seconds = int(_time_left)
	var minutes = seconds / 60
	var secs = seconds % 60
	return "%02d:%02d" % [minutes, secs]

func get_seconds() -> int:
	return int(_time_left)

func get_minutes() -> float:
	return _time_left / 60.0

func is_active() -> bool:
	return _is_running and not _is_paused

# ========== 快捷功能 ==========

func set_5min():
	set_time(5)

func set_15min():
	set_time(15)

func set_25min():
	set_time(25)

func set_30min():
	set_time(30)

func set_45min():
	set_time(45)

func set_custom(minutes: int):
	if minutes > 0:
		set_time(minutes)

# ========== 编辑器中显示属性 ==========
func _get_property_list():
	return [
		{
			"name": "TimeLeft",
			"type": TYPE_FLOAT,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		},
		{
			"name": "IsRunning",
			"type": TYPE_BOOL,
			"usage": PROPERTY_USAGE_EDITOR | PROPERTY_USAGE_READ_ONLY
		}
	]

func _get(property: StringName) -> Variant:
	match property:
		"TimeLeft":
			return _time_left
		"IsRunning":
			return _is_running
	return null

func _set(property: StringName, value: Variant) -> bool:
	match property:
		"TimeLeft":
			_time_left = float(value)
			_update_display()
			return true
		"IsRunning":
			_is_running = bool(value)
			return true
	return false
