extends Node3D

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

# ✅ 闭眼参数（形态键名称改为"眨眼"）
@export var eye_blend_name: String = "眨眼"  # 改成"眨眼"
@export var eye_close_amount: float = 1.0
@export var eye_close_speed: float = 4.0

# 手动测试开关
@export var test_eye_close: float = 0.0

var _bone_idx: int = -1
var _is_petting: bool = false
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
	
	# 如果 mesh_instance 没赋值，自动查找
	if not mesh_instance:
		print("🔍 自动查找头部网格...")
		mesh_instance = find_head_mesh()
		
		if mesh_instance:
			print("✅ 找到头部网格：", mesh_instance.name)
		else:
			push_error("❌ 找不到头部网格，请手动拖拽")
			return
	
	# ========== 形态键调试 ==========
	print("========== 形态键调试 ==========")
	
	if not mesh_instance:
		push_error("❌ mesh_instance 为空")
		return
	
	if not mesh_instance.mesh:
		push_error("❌ mesh_instance 没有 Mesh")
		return
	
	print("网格名称：", mesh_instance.name)
	
	var mesh = mesh_instance.mesh
	var count = mesh.get_blend_shape_count()
	print("形态键数量：", count)
	
	if count == 0:
		push_error("❌ 这个网格没有任何形态键！")
		return
	
	print("形态键列表：")
	for i in range(count):
		var name = mesh.get_blend_shape_name(i)
		print("  [", i, "] ", name)
		
		# ✅ 匹配"眨眼"
		if name == eye_blend_name:
			_blend_idx = i
			print("✅ 找到匹配的形态键：", name)
	
	if _blend_idx == -1:
		print("⚠️ 没有找到 '", eye_blend_name, "'")
		print("请从上面的列表中选择正确的名称")
	
	print("====================================")
	print("✅ 头部抚摸系统已初始化")

func find_head_mesh() -> MeshInstance3D:
	if head_attach:
		for child in head_attach.get_children():
			if child is MeshInstance3D:
				return child
	return null

func _process(delta: float) -> void:
	if _bone_idx == -1 or not head_attach:
		return
	
	# 手动测试闭眼
	if test_eye_close > 0 and _blend_idx != -1 and mesh_instance and mesh_instance.mesh:
		mesh_instance.set_blend_shape_value(_blend_idx, test_eye_close)
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
	
	# ========== 2. 抚摸状态机 ==========
	if is_hovering and not _is_petting:
		_is_petting = true
		_pet_timer = 0.0
		_target_transition = 1.0
		_target_eye_close = eye_close_amount
		print("✅ 抚摸开始！闭眼")
	elif not is_hovering and _is_petting:
		_pet_timer += delta
		if _pet_timer > pet_duration:
			_is_petting = false
			_target_transition = 0.0
			_target_eye_close = 0.0
			print("✅ 抚摸结束，睁眼")
	
	# 过渡插值
	_current_transition = move_toward(_current_transition, _target_transition, delta / transition_time)
	var strength = _current_transition
	
	if strength > 0.01:
		var target_yaw = x_rel * max_angle * yaw_intensity
		var target_pitch = head_down_angle + y_rel * max_angle * pitch_intensity
		
		if abs(x_rel) < 0.15 and y_rel < -0.3:
			target_yaw = 0.0
			target_pitch = head_down_angle * 1.5
		
		_target_yaw = target_yaw * strength
		_target_pitch = target_pitch * strength
	else:
		_target_yaw = 0.0
		_target_pitch = 0.0
	
	# 平滑插值（头部旋转）
	var smooth_factor = 1.0 - exp(-smooth_speed * delta)
	_current_yaw = lerp(_current_yaw, _target_yaw, smooth_factor)
	_current_pitch = lerp(_current_pitch, _target_pitch, smooth_factor)
	
	# 平滑插值（闭眼）
	var eye_smooth_factor = 1.0 - exp(-eye_close_speed * delta)
	_current_eye_close = lerp(_current_eye_close, _target_eye_close, eye_smooth_factor)
	
	# ========== 3. 应用头部旋转 ==========
	var rot = Basis.IDENTITY
	rot = rot.rotated(Vector3.UP, _current_yaw)
	rot = rot.rotated(rot.x, _current_pitch)
	
	var pose = skeleton.get_bone_global_pose(_bone_idx)
	pose.basis = pose.basis * rot
	skeleton.set_bone_global_pose_override(_bone_idx, pose, 1.0, false)
	
	# ========== 4. 应用闭眼形态键 ==========
	if _blend_idx != -1 and mesh_instance and mesh_instance.mesh:
		mesh_instance.set_blend_shape_value(_blend_idx, _current_eye_close)
