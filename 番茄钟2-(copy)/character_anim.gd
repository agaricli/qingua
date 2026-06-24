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
@export var transition_time: float = 0.1

var _is_working: bool = false
var _current_state_name: String = "" # 【新增】用变量记录当前状态，比 get_current_node() 更稳
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

	# 初始状态
	_switch_to_state(IDLE_STATE)

# 统一的切换函数，避免到处写 travel
func _switch_to_state(target_state: String) -> void:
	if not _playback or not _state_machine.has_node(target_state):
		print("❌ 无法切换到 [", target_state, "]：节点不存在或播放器无效")
		return

	print("🔄 正在尝试切换到：", target_state)
	_playback.travel(target_state)
	_current_state_name = target_state # 【关键】立即更新内部记录的状态

# 入口：开始工作循环
func play_random_work() -> void:
	if _is_working:
		return # 防止重复触发

	_is_working = true
	_timer_version += 1 # 版本号加1，作废旧的定时器

	# 1. 先切到一个随机的工作动画
	var first_work = WORK_STATES[randi() % WORK_STATES.size()]
	_switch_to_state(first_work)

	# 2. 启动第一个定时器
	_schedule_next_action(first_work, _timer_version)

# 定时器结束时的回调
func _on_anim_cycle_end() -> void:
	# 如果版本号变了，说明这是过期的定时器，直接忽略
	if _timer_version != _anim_timer.get_meta("version", -1):
		return

	if not _is_working:
		_switch_to_state(IDLE_STATE)
		return

	var current = _current_state_name # 使用内部变量，不再依赖 get_current_node()

	# 决定下一步：重播还是换新
	var next_state: String
	if randf() < replay_chance:
		next_state = current # 重播自己
	else:
		next_state = _pick_different_work_anim(current)

	# 执行切换
	_switch_to_state(next_state)

	# 继续排期下一次
	_schedule_next_action(next_state, _timer_version)

# 辅助：计算时间并启动定时器
func _schedule_next_action(state_name: String, version: int) -> void:
	var duration = STATE_LENGTH.get(state_name, 2.0)
	# 稍微提前一点点切换，避免动作完全静止的尴尬期
	var wait_time = max(duration - 0.1, 0.2)

	_anim_timer.wait_time = wait_time
	_anim_timer.set_meta("version", version) # 给定时器打上版本号标签
	_anim_timer.start()

# 辅助：随机选一个不同的动画
func _pick_different_work_anim(current: String) -> String:
	var candidates = WORK_STATES.duplicate()
	candidates.erase(current)
	if candidates.is_empty():
		return WORK_STATES[0]
	return candidates[randi() % candidates.size()]

# 停止工作，回到待机
func stop_work():
	_is_working = false
	_timer_version += 1
	_anim_timer.stop()
	_switch_to_state(IDLE_STATE)
