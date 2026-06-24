extends Node3D

@onready var anim_tree: AnimationTree = $AnimationTree
var _playback: AnimationNodeStateMachinePlayback
var _state_machine: AnimationNodeStateMachine

# 【配置区】确保这里的名字和编辑器里的一模一样（区分大小写和空格）
const IDLE_STATE: String = "idle"
const WORK_STATES: Array[String] = ["看书", "托腮眨眼", "托腮无表情"]

const STATE_LENGTH: Dictionary = {
	"看书": 4.0,
	"托腮眨眼": 3.5,
	"托腮无表情": 5.0
}

@export var replay_chance: float = 0.2
@export var idle_transition_time: float = 0.8  # 👈 新增：回到idle的过渡时间

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

	# 初始化定时器
	_anim_timer = Timer.new()
	_anim_timer.one_shot = true
	_anim_timer.timeout.connect(_on_anim_cycle_end)
	add_child(_anim_timer)

	# 初始状态：进入待机
	play_idle()

# =============================================
# 公共方法 - 供番茄钟调用
# =============================================

# 进入待机状态（使用过渡动画）
func play_idle() -> void:
	print("🛑 回到待机状态")
	if _is_working:
		_is_working = false
		_timer_version += 1       # 作废旧定时器
		_anim_timer.stop()
	
	# 使用travel而非start，走状态机过渡
	_switch_to_state(IDLE_STATE, false)

# 开始随机工作动画循环
func play_random_work() -> void:
	if _is_working:
		print("⚠️ 已经在工作中，不重复触发")
		return

	print("▶️ 开始工作动画循环")
	_is_working = true
	_timer_version += 1

	# 随机选一个工作动画开始
	var first_work = WORK_STATES[randi() % WORK_STATES.size()]
	_switch_to_state(first_work, false)  # 也用travel，走过渡

	# 启动循环定时器
	_schedule_next_action(first_work, _timer_version)

# =============================================
# 内部实现
# =============================================

# 统一的切换函数
func _switch_to_state(target_state: String, force: bool = false) -> void:
	if not _playback or not _state_machine.has_node(target_state):
		print("❌ 无法切换到 [", target_state, "]：节点不存在或播放器无效")
		return

	print("🔄 切换到：", target_state, " | 方式：", "强制" if force else "过渡")
	
	if force:
		_playback.start(target_state)      # 立刻跳转，无过渡
	else:
		_playback.travel(target_state)     # 通过状态机过渡切换
		
	_current_state_name = target_state

# 计算时间并启动定时器
func _schedule_next_action(state_name: String, version: int) -> void:
	var duration = STATE_LENGTH.get(state_name, 2.0)
	# 提前一点切换，让过渡有足够时间完成
	var wait_time = max(duration - idle_transition_time, 0.3)
	
	print("⏰ 下一次切换在 ", wait_time, " 秒后")
	_anim_timer.wait_time = wait_time
	_anim_timer.set_meta("version", version)
	_anim_timer.start()

# 定时器结束时的回调
func _on_anim_cycle_end() -> void:
	# 版本号对不上，说明是过期的定时器，忽略
	var timer_version = _anim_timer.get_meta("version", -1)
	if _timer_version != timer_version:
		print("⏭️ 忽略过期定时器 (版本:", timer_version, "当前:", _timer_version, ")")
		return

	# 如果已经停止工作，回到idle
	if not _is_working:
		print("🔙 工作已停止，回到idle")
		_switch_to_state(IDLE_STATE, false)
		return

	# 决定是重播还是换下一个
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

# 随机选一个不同的动画
func _pick_different_work_anim(current: String) -> String:
	var candidates = WORK_STATES.duplicate()
	candidates.erase(current)
	if candidates.is_empty():
		return WORK_STATES[0]
	return candidates[randi() % candidates.size()]
