extends Control

# ========== 编辑器可配置参数 ==========
@export var dialog_label: Label
@export var character_node: Node3D

# 待机台词库 - idle动画时播放
@export var idle_dialog_texts: Array[String] = [
	"休息一下眼睛吧～",
	"要不要喝口水？",
	"今天状态不错呀",
	"累了就歇会儿",
	"坐久了站起来活动活动",
	"加油，专注的你超棒的",
    "要不要吃点小零食？"
]

# 计时台词库 - 工作动画时播放
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
@export var check_interval: float = 0.2
# ======================================

var _dialog_timer: Timer
var _check_timer: Timer
var _anim_tree: AnimationTree
var _is_idle: bool = true

func _ready():
	if not dialog_label:
		print("❌ 错误：dialog_label 未绑定")
	else:
		print("✅ dialog_label 绑定成功")
		dialog_label.visible = false
	
	# 先创建并添加定时器到场景树
	_dialog_timer = Timer.new()
	_dialog_timer.one_shot = true
	_dialog_timer.timeout.connect(_show_next_dialog)
	add_child(_dialog_timer)
	
	_check_timer = Timer.new()
	_check_timer.wait_time = check_interval
	_check_timer.timeout.connect(_check_character_state)
	add_child(_check_timer)
	_check_timer.start()  # 加入树之后再启动
	
	# 获取角色动画树
	if character_node:
		_anim_tree = character_node.get_node_or_null("AnimationTree")
		if _anim_tree:
			print("✅ 角色动画树绑定成功")
		else:
			print("⚠️ 角色下未找到 AnimationTree，默认待机台词")
	else:
		print("⚠️ 未绑定角色节点，默认待机台词")
	
	# 最后启动对话循环
	_start_dialog_cycle()

# ========== 检测动画状态 ==========
func _check_character_state() -> void:
	# 检查动画树是否有效
	if not _anim_tree:
		return
	
	# 检查是否有 playback 参数
	if not _anim_tree.has("parameters/playback"):
		return
	
	# 安全获取 playback
	var playback = _anim_tree.get("parameters/playback")
	if not playback:
		return
	
	# 安全检查：判断是否有 get_current_node 方法
	if not playback.has_method("get_current_node"):
		return
	
	# 获取当前状态
	var current_state: String = playback.get_current_node()
	
	# 判断是否为 idle
	var now_idle = (current_state == "idle")
	if now_idle != _is_idle:
		_is_idle = now_idle
		print("状态切换：", "待机台词" if _is_idle else "计时台词")
		_stop_dialog()
		_start_dialog_cycle()

# ========== 对话循环 ==========
func _start_dialog_cycle() -> void:
	if not is_instance_valid(_dialog_timer) or not is_inside_tree():
		return
	_dialog_timer.stop()
	var interval = randf_range(interval_min, interval_max)
	_dialog_timer.wait_time = interval
	_dialog_timer.start()

func _stop_dialog() -> void:
	if not is_instance_valid(_dialog_timer):
		return
	_dialog_timer.stop()
	if dialog_label:
		dialog_label.visible = false

func _show_next_dialog() -> void:
	if not dialog_label:
		return
	
	var text_list = idle_dialog_texts if _is_idle else work_dialog_texts
	if text_list.is_empty():
		return
	
	var text = text_list[randi() % text_list.size()]
	dialog_label.text = text
	dialog_label.visible = true
	
	# 使用 Timer 代替 await，更安全
	var hide_timer = Timer.new()
	hide_timer.one_shot = true
	hide_timer.wait_time = display_time
	hide_timer.timeout.connect(_on_dialog_hide_timeout)
	add_child(hide_timer)
	hide_timer.start()

func _on_dialog_hide_timeout() -> void:
	if is_instance_valid(dialog_label):
		dialog_label.visible = false
	# 清理定时器
	var timer = get_tree().current_scene.find_child("Timer", true, false)
	if timer and timer != _dialog_timer and timer != _check_timer:
		timer.queue_free()
	
	_start_dialog_cycle()
