extends Node3D

@onready var anim_tree: AnimationTree = $AnimationTree
var _playback: AnimationNodeStateMachinePlayback

const IDLE_STATE: String = "idle"
const WORK_STATES: Array[String] = ["看书", "托腮眨眼", "托腮无表情"]

const STATE_LENGTH: Dictionary = {
	"看书": 4.0,
	"托腮眨眼": 3.5,
	"托腮无表情": 5.0
}

@export var replay_chance: float = 0.2
@export var transition_time: float = 0.1

var _is_working: bool = false
var _anim_timer: Timer
var _timer_version: int = 0

func _ready():
	# 安全获取状态机，配置错误也不崩溃
	if anim_tree and anim_tree.has_parameter("playback"):
		_playback = anim_tree["parameters/playback"]
		print("✅ 动画状态机加载成功")
	else:
		print("❌ 动画树配置错误：找不到 playback 参数，请确认根节点是状态机")
		return
	
	_anim_timer = Timer.new()
	_anim_timer.one_shot = true
	_anim_timer.timeout.connect(_on_anim_cycle_end)
	add_child(_anim_timer)
	
	play_idle()

func play_idle() -> void:
	if not _playback:
		return
	_is_working = false
	_anim_timer.stop()
	_timer_version += 1
	
	# 节点存在才切换，避免报错
	if _playback.has_node(IDLE_STATE):
		_playback.travel(IDLE_STATE)
	else:
		print("❌ 状态机中找不到 idle 节点，请检查节点名称是否为 ", IDLE_STATE)

func play_random_work() -> void:
	if not _playback or WORK_STATES.is_empty():
		return
	
	_is_working = true
	var current = _playback.get_current_node()
	var target = _pick_different_work_anim(current)
	
	if _playback.has_node(target):
		_playback.travel(target)
		_restart_anim_timer()
	else:
		print("❌ 状态机中找不到工作节点：", target)

func _pick_different_work_anim(current: String) -> String:
	if WORK_STATES.size() <= 1:
		return WORK_STATES[0]
	var candidates = WORK_STATES.duplicate()
	candidates.erase(current)
	return candidates[randi() % candidates.size()]

func _restart_anim_timer() -> void:
	_timer_version += 1
	var my_version = _timer_version
	
	await get_tree().process_frame
	
	if my_version != _timer_version or not _is_working:
		return
	
	var current_state = _playback.get_current_node()
	var anim_length = STATE_LENGTH.get(current_state, 2.0)
	
	var wait_time = max(anim_length - 0.05, 0.1)
	_anim_timer.wait_time = wait_time
	_anim_timer.start()

func _on_anim_cycle_end() -> void:
	if not _is_working or not _playback:
		return
	
	var current = _playback.get_current_node()
	if not WORK_STATES.has(current):
		return
	
	if randf() < replay_chance:
		_playback.travel(current)
	else:
		var target = _pick_different_work_anim(current)
		_playback.travel(target)
	
	_restart_anim_timer()
