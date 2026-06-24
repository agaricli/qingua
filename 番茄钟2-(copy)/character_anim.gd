extends Node3D

@onready var anim_tree: AnimationTree = $AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _state_machine: AnimationNodeStateMachine

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
	# 获取状态机节点（通过 tree_root）
	var tree_root = anim_tree.tree_root
	if not tree_root:
		print("❌ AnimationTree 没有设置 tree_root")
		return
	if not (tree_root is AnimationNodeStateMachine):
		print("❌ tree_root 不是状态机，实际类型：", tree_root.get_class())
		return
	_state_machine = tree_root
	print("✅ 状态机获取成功")

	# 获取播放器
	_playback = anim_tree.get("parameters/playback")
	if not _playback:
		print("❌ 获取 playback 失败")
		return
	print("✅ 动画播放器获取成功")

	_anim_timer = Timer.new()
	_anim_timer.one_shot = true
	_anim_timer.timeout.connect(_on_anim_cycle_end)
	add_child(_anim_timer)

	play_idle()

func _exit_tree():
	if _anim_timer:
		_anim_timer.stop()

func play_idle() -> void:
	if not _playback:
		return
	_is_working = false
	_anim_timer.stop()
	_timer_version += 1

	# 若状态机有效则检查，否则直接切换
	if _state_machine and _state_machine.has_node(IDLE_STATE):
		_playback.travel(IDLE_STATE)
	else:
		_playback.travel(IDLE_STATE)

func play_random_work() -> void:
	if not _playback or WORK_STATES.is_empty():
		return

	_is_working = true
	var current = _playback.get_current_node()
	var target = _pick_different_work_anim(current)

	if _state_machine and _state_machine.has_node(target):
		_playback.travel(target)
	else:
		_playback.travel(target)
	_restart_anim_timer()

func _pick_different_work_anim(current: String) -> String:
	if WORK_STATES.size() <= 1:
		return WORK_STATES[0]
	var candidates = WORK_STATES.duplicate()
	candidates.erase(current)
	if candidates.is_empty():
		return WORK_STATES[randi() % WORK_STATES.size()]
	return candidates[randi() % candidates.size()]

func _restart_anim_timer() -> void:
	_timer_version += 1
	var my_version = _timer_version
	call_deferred("_deferred_start_timer", my_version)

func _deferred_start_timer(my_version: int) -> void:
	if my_version != _timer_version or not _is_working:
		return
	if not _playback:
		return

	var current_state = _playback.get_current_node()
	if not WORK_STATES.has(current_state):
		play_idle()
		return

	var anim_length = STATE_LENGTH.get(current_state, 2.0)
	var wait_time = max(anim_length - 0.05, 0.1)
	_anim_timer.wait_time = wait_time
	_anim_timer.start()

func _on_anim_cycle_end() -> void:
	if not _is_working or not _playback:
		return

	var current = _playback.get_current_node()
	if not WORK_STATES.has(current):
		play_idle()
		return

	if randf() < replay_chance:
		_playback.travel(current)
	else:
		var target = _pick_different_work_anim(current)
		_playback.travel(target)

	_restart_anim_timer()
