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
@export var idle_transition_time: float = 0.8

var _is_working: bool = false
var _current_state_name: String = ""
var _anim_timer: Timer
var _timer_version: int = 0

func _ready():
	var tree_root = anim_tree.tree_root
	if not (tree_root is AnimationNodeStateMachine):
		print("❌ 错误：AnimationTree 根节点不是状态机")
		return

	_state_machine = tree_root
	_playback = anim_tree.get("parameters/playback")

	_anim_timer = Timer.new()
	_anim_timer.one_shot = true
	_anim_timer.timeout.connect(_on_anim_cycle_end)
	add_child(_anim_timer)

	# ✅ 连接信号总线
	if SignalBus.instance:
		SignalBus.instance.anim_play_idle.connect(play_idle)
		SignalBus.instance.anim_play_work.connect(play_random_work)
		print("✅ 已连接到信号总线（动画控制）")
	else:
		print("⚠️ SignalBus 未找到")

	play_idle()

# =============================================
# 公共方法
# =============================================

func play_idle() -> void:
	print("🛑 回到待机状态（信号触发）")
	if _is_working:
		_is_working = false
		_timer_version += 1
		_anim_timer.stop()
	
	_switch_to_state(IDLE_STATE, false)

func play_random_work() -> void:
	if _is_working:
		print("⚠️ 已经在工作中，不重复触发")
		return

	print("▶️ 开始工作动画循环（信号触发）")
	_is_working = true
	_timer_version += 1

	var first_work = WORK_STATES[randi() % WORK_STATES.size()]
	_switch_to_state(first_work, false)

	_schedule_next_action(first_work, _timer_version)

# =============================================
# 内部实现
# =============================================

func _switch_to_state(target_state: String, force: bool = false) -> void:
	if not _playback or not _state_machine.has_node(target_state):
		print("❌ 无法切换到 [", target_state, "]：节点不存在或播放器无效")
		return

	print("🔄 切换到：", target_state, " | 方式：", "强制" if force else "过渡")
	
	if force:
		_playback.start(target_state)
	else:
		_playback.travel(target_state)
		
	_current_state_name = target_state

func _schedule_next_action(state_name: String, version: int) -> void:
	var duration = STATE_LENGTH.get(state_name, 2.0)
	var wait_time = max(duration - idle_transition_time, 0.3)
	
	print("⏰ 下一次切换在 ", wait_time, " 秒后")
	_anim_timer.wait_time = wait_time
	_anim_timer.set_meta("version", version)
	_anim_timer.start()

func _on_anim_cycle_end() -> void:
	var timer_version = _anim_timer.get_meta("version", -1)
	if _timer_version != timer_version:
		print("⏭️ 忽略过期定时器 (版本:", timer_version, "当前:", _timer_version, ")")
		return

	if not _is_working:
		print("🔙 工作已停止，回到idle")
		_switch_to_state(IDLE_STATE, false)
		return

	var current = _current_state_name
	var next_state: String
	
	if randf() < replay_chance:
		next_state = current
		print("🔄 重播：", next_state)
	else:
		next_state = _pick_different_work_anim(current)
		print("➡️ 切换到：", next_state)

	_switch_to_state(next_state, false)
	_schedule_next_action(next_state, _timer_version)

func _pick_different_work_anim(current: String) -> String:
	var candidates = WORK_STATES.duplicate()
	candidates.erase(current)
	if candidates.is_empty():
		return WORK_STATES[0]
	return candidates[randi() % candidates.size()]
