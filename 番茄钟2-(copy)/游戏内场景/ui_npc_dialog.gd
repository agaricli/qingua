extends Control

@export var dialog_label: Label
@export var character_node: Node3D
@export var tomato_timer: Node

@export var idle_dialog_texts: Array[String] = [
	"休息一下眼睛吧～",
	"要不要喝口水？",
	"今天状态不错呀",
	"累了就歇会儿",
	"坐久了站起来活动活动",
	"加油，专注的你超棒的",
    "要不要吃点小零食？"
]

@export var work_dialog_texts: Array[String] = [
	"保持专注，继续加油！",
	"进度很不错哦～",
	"沉下心来，效率拉满",
	"再坚持一会儿就休息啦",
	"认真的样子超棒的",
	"别走神，继续冲！",
    "专注时长正在累积中"
]

@export var interval_min: float = 2.0
@export var interval_max: float = 4.0
@export var display_time: float = 2.5
@export var check_interval: float = 0.3

var _dialog_timer: Timer
var _check_timer: Timer
var _is_timing: bool = false

func _ready():
	if not dialog_label:
		print("❌ 错误：dialog_label 未绑定")
		return
	
	dialog_label.visible = false
	
	_dialog_timer = Timer.new()
	_dialog_timer.one_shot = true
	_dialog_timer.timeout.connect(_show_next_dialog)
	add_child(_dialog_timer)
	
	_check_timer = Timer.new()
	_check_timer.wait_time = check_interval
	_check_timer.timeout.connect(_check_tomato_state)
	add_child(_check_timer)
	_check_timer.start()
	
	# 自动查找番茄钟（如果没手动拖）
	if not tomato_timer:
		tomato_timer = get_node_or_null("../Clock")
		if not tomato_timer:
			tomato_timer = get_node_or_null("../../Clock")
		if not tomato_timer:
			tomato_timer = get_node_or_null("/root/Main/Clock")
	
	if tomato_timer:
		print("✅ 番茄钟绑定成功：", tomato_timer.name)
	else:
		print("⚠️ 未找到番茄钟，将一直使用待机台词")
	
	_start_dialog_cycle()

func _check_tomato_state() -> void:
	if not tomato_timer:
		return
	if not "is_running" in tomato_timer:
		print("❌ tomato_timer 没有 is_running 属性")
		return
	
	var now_timing = tomato_timer.get("is_running")
	if now_timing == null:
		now_timing = false
	
	if now_timing != _is_timing:
		_is_timing = now_timing
		print("🔄 对话切换 -> ", "计时台词(B)" if _is_timing else "待机台词(A)")
		_stop_dialog()
		_show_next_dialog()          # 立刻显示一句
		_start_dialog_cycle()        # 恢复定时循环
	# 可取消注释下面这段，每10秒打印当前状态方便观察
	# else:
	#     print("当前状态：", "计时中" if _is_timing else "未计时")

func _start_dialog_cycle() -> void:
	if not is_instance_valid(_dialog_timer) or not is_inside_tree():
		return
	_dialog_timer.stop()
	var interval = randf_range(interval_min, interval_max)
	_dialog_timer.wait_time = interval
	_dialog_timer.start()

func _stop_dialog() -> void:
	if is_instance_valid(_dialog_timer):
		_dialog_timer.stop()
	if dialog_label:
		dialog_label.visible = false

func _show_next_dialog() -> void:
	if not dialog_label:
		return
	var text_list = idle_dialog_texts if not _is_timing else work_dialog_texts
	if text_list.is_empty():
		return
	var text = text_list[randi() % text_list.size()]
	dialog_label.text = text
	dialog_label.visible = true
	
	var hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.wait_time = display_time
	hide_timer.timeout.connect(_on_dialog_hide_timeout)
	add_child(hide_timer)
	hide_timer.start()

func _on_dialog_hide_timeout() -> void:
	if is_instance_valid(dialog_label):
		dialog_label.visible = false
	# 清理临时定时器
	var timers = get_children().filter(func(t): return t is Timer and t != _dialog_timer and t != _check_timer)
	for t in timers:
		t.queue_free()
	_start_dialog_cycle()
