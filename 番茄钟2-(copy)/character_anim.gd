extends Node3D

@onready var anim_tree: AnimationTree = $AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _state_machine: AnimationNodeStateMachine

# ========== 【已根据日志修正节点名称】==========
# 注意：idle 后面有个空格，必须完全匹配
const IDLE_STATE: String = "idle "
const WORK_STATES: Array[String] = ["看书", "托腮眨眼", "托腮无表情"]
# =============================================

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
	var tree_root = anim_tree.tree_root
	if not tree_root:
		print("❌ AnimationTree 没有设置 tree_root")
		return
	if not (tree_root is AnimationNodeStateMachine):
		print("❌ tree_root 不是状态机，实际类型：", tree_root.get_class())
		return
	_state_machine = tree_root
	print("✅ 状态机获取成功")
	
	var all_states = _state_machine.get_node_list()
	print("📋 状态机中所有节点名称：", all_states)

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

	if _state_machine and _state_machine.has_node(IDLE_STATE):
		_playback.travel(IDLE_STATE)
		print("✅ 切换到 idle 状态")
	else:
		print("❌ 仍然找不到 idle 节点！当前节点列表：", _state_machine.get_node_list() if _state_machine else "无")

# ========== 【临时验证版本】注释掉定时器启动 ==========
func play_random_work() -> void:
	print("✅ 角色收到切换工作动画请求")
	if not _playback or WORK_STATES.is_empty():
		print("❌ 播放器无效或工作动画列表为空")
		return

	_is_working = true
	var current = _playback.get_current_node()
	print("切换前当前节点：", current)
	
	var target = _pick_different_work_anim(current)
	print("目标切换节点：", target)
	
	if _state_machine and not _state_machine.has_node(target):
		print("❌ 状态机中找不到节点：", target)
		print("可用节点列表：", _state_machine.get_node_list())
		return

	_playback.travel(target)
	await get_tree().process_frame
	var after = _playback.get_current_node()
	print("切换后当前节点：", after)
	
	if after == target:
		print("✅ 节点切换成功")
	else:
		print("❌ 节点切换失败，仍停留在：", after)
		print("👉 请检查节点之间是否有过渡连线")
		print("👉 当前状态 [", after, "] 到目标 [", target, "] 必须有过渡连线")

	# ========== 【临时注释】排除定时器干扰 ==========
	# _restart_anim_timer()   # 先注释掉，只验证切换
	# ===============================================
# ===================================================

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
