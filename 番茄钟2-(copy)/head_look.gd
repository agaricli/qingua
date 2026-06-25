extends Node3D

# ========== 编辑器参数 ==========
@export var skeleton: Skeleton3D
@export var head_bone_name: String = "头"
@export var head_attach: BoneAttachment3D
@export var mesh_instance: MeshInstance3D

# 抚摸参数
@export var trigger_radius: float = 180.0
@export var smooth_speed: float = 6.0
@export var max_angle: float = deg_to_rad(35)
@export var pet_offset: Vector2 = Vector2(0, -200)
@export var head_down_angle: float = deg_to_rad(20)
@export var pet_duration: float = 0.5
@export var transition_time: float = 0.3
@export var yaw_intensity: float = 1.0
@export var pitch_intensity: float = 0.5

# 闭眼参数
@export var eye_blend_name: String = "眨眼"
@export var eye_close_amount: float = 1.0
@export var eye_close_speed: float = 4.0

var _bone_idx: int = -1
var _is_petting: bool = false
var _is_mouse_down: bool = false
var _is_hovering: bool = false
var _pet_timer: float = 0.0
var _target_transition: float = 0.0
var _current_transition: float = 0.0

var _target_yaw: float = 0.0
var _target_pitch: float = 0.0
var _current_yaw: float = 0.0
var _current_pitch: float = 0.0

var _target_eye_close: float = 0.0
var _current_eye_close: float = 0.0
var _blend_idx: int = -1

var _speak_cooldown: float = 0.0

@onready var _camera: Camera3D

func _ready():
	process_priority = 9999
	_camera = get_viewport().get_camera_3d()
	
	if not skeleton:
		push_error("❌ skeleton 未赋值")
		return
	
	_bone_idx = skeleton.find_bone(head_bone_name)
	if _bone_idx == -1:
		push_error("❌ 找不到骨骼：", head_bone_name)
		return
	
	if not head_attach:
		push_error("❌ head_attach 未赋值")
		return
	
	if not mesh_instance:
		mesh_instance = find_head_mesh()
	
	if mesh_instance and mesh_instance.mesh:
		var mesh = mesh_instance.mesh
		for i in range(mesh.get_blend_shape_count()):
			var name = mesh.get_blend_shape_name(i)
			if name == eye_blend_name:
				_blend_idx = i
				print("✅ 找到形态键：", name)
				break
	
	if not SignalBus.instance:
		push_error("❌ SignalBus 未初始化！请检查 AutoLoad 设置")
	
	print("✅ 头部抚摸系统已初始化（鼠标按下触发）")

# ========== ✅ 使用 _input 处理鼠标事件 ==========
func _input(event: InputEvent):
	# 鼠标左键按下
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_is_mouse_down = true
				print("🖱️ 鼠标按下")
				# 检查是否在头部区域
				_check_petting_state()
			else:
				_is_mouse_down = false
				print("🖱️ 鼠标抬起")
				# 鼠标抬起时停止抚摸
				if _is_petting:
					_stop_petting()

func find_head_mesh() -> MeshInstance3D:
	if head_attach:
		for child in head_attach.get_children():
			if child is MeshInstance3D:
				return child
	return null

func _process(delta: float) -> void:
	if _bone_idx == -1 or not head_attach:
		return
	
	# ========== 1. 检测鼠标位置 ==========
	var head_world_pos = head_attach.global_position
	var head_screen_pos = _camera.unproject_position(head_world_pos)
	var pet_detect_pos = head_screen_pos + pet_offset
	
	var mouse_pos = get_viewport().get_mouse_position()
	var distance = pet_detect_pos.distance_to(mouse_pos)
	
	var relative_offset = (mouse_pos - pet_detect_pos) / trigger_radius
	var x_rel = clamp(relative_offset.x, -1.0, 1.0)
	var y_rel = clamp(relative_offset.y, -1.0, 1.0)
	
	var is_hovering = distance < trigger_radius
	
	_is_hovering = is_hovering
	
	# ✅ 如果鼠标移出头部区域，停止抚摸
	if _is_petting and not _is_hovering:
		print("🚫 鼠标移出头部区域，停止抚摸")
		_stop_petting()
		return
	
	# ========== 2. 抚摸状态机（鼠标按下 + 悬停） ==========
	if _is_mouse_down and _is_hovering and not _is_petting:
		_start_petting()
	
	# ========== 3. 处理抚摸中的逻辑 ==========
	if _is_petting:
		_speak_cooldown += delta
		if _speak_cooldown >= 2.0:
			if randf() < 0.2:
				if SignalBus.instance:
					SignalBus.instance.pet_dialog_triggered.emit("")
				_speak_cooldown = 0.0
		
		var target_yaw = x_rel * max_angle * yaw_intensity
		var target_pitch = head_down_angle + y_rel * max_angle * pitch_intensity
		
		if abs(x_rel) < 0.15 and y_rel < -0.3:
			target_yaw = 0.0
			target_pitch = head_down_angle * 1.5
		
		_target_yaw = target_yaw * _current_transition
		_target_pitch = target_pitch * _current_transition
		
		_current_transition = move_toward(_current_transition, 1.0, delta / transition_time)
	else:
		_target_yaw = 0.0
		_target_pitch = 0.0
		_current_transition = move_toward(_current_transition, 0.0, delta / transition_time)
	
	var smooth_factor = 1.0 - exp(-smooth_speed * delta)
	_current_yaw = lerp(_current_yaw, _target_yaw, smooth_factor)
	_current_pitch = lerp(_current_pitch, _target_pitch, smooth_factor)
	
	var eye_smooth_factor = 1.0 - exp(-eye_close_speed * delta)
	_current_eye_close = lerp(_current_eye_close, _target_eye_close, eye_smooth_factor)
	
	# ========== 4. 应用头部旋转 ==========
	var rot = Basis.IDENTITY
	rot = rot.rotated(Vector3.UP, _current_yaw)
	rot = rot.rotated(rot.x, _current_pitch)
	
	var pose = skeleton.get_bone_global_pose(_bone_idx)
	pose.basis = pose.basis * rot
	skeleton.set_bone_global_pose_override(_bone_idx, pose, 1.0, false)
	
	# ========== 5. 应用闭眼形态键 ==========
	if _blend_idx != -1 and mesh_instance and mesh_instance.mesh:
		mesh_instance.set_blend_shape_value(_blend_idx, _current_eye_close)

# ========== 开始抚摸 ==========
func _start_petting():
	if _is_petting:
		return
	
	_is_petting = true
	_pet_timer = 0.0
	_target_transition = 1.0
	_target_eye_close = eye_close_amount
	_speak_cooldown = 0.0
	
	if SignalBus.instance:
		SignalBus.instance.petting_started.emit()
		SignalBus.instance.pet_dialog_triggered.emit("")
	
	print("✅ 抚摸开始！（鼠标按下）")

# ========== 停止抚摸 ==========
func _stop_petting():
	if not _is_petting:
		return
	
	_is_petting = false
	_target_transition = 0.0
	_target_eye_close = 0.0
	
	if SignalBus.instance:
		SignalBus.instance.petting_ended.emit()
	
	print("✅ 抚摸结束（鼠标抬起/移出）")

func _check_petting_state():
	if _is_mouse_down and _is_hovering and not _is_petting:
		_start_petting()

func is_petting() -> bool:
	return _is_petting
