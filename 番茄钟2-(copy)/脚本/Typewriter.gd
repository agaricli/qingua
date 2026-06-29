class_name DialogTypewriter
extends Node

# ========== 信号 ==========
signal typing_finished()
signal char_typed(char: String, index: int)

# ========== 导出参数 ==========
@export var label: Label
@export var type_speed: float = 0.05
@export var enable_sound: bool = true

# 语音系统
@export var voice_system: VoiceSystem
@export var voice_enabled: bool = true
@export var voice_speed_multiplier: float = 1.0

# 音效系统（备用）
@export var type_sound: AudioStreamPlayer
@export var type_sound_interval: int = 2
@export var finish_sound: AudioStreamPlayer

# ========== 私有变量 ==========
var _is_typing: bool = false
var _full_text: String = ""
var _current_index: int = 0
var _timer: Timer
var _callback: Callable
var _char_count_since_sound: int = 0

# ========== 初始化 ==========
func _ready():
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)
	
	if not voice_system:
		voice_system = _find_voice_system(get_tree().root)
		if voice_system:
			print("✅ 自动找到 VoiceSystem")
		else:
			print("⚠️ 未找到 VoiceSystem")

func _find_voice_system(node: Node) -> VoiceSystem:
	for child in node.get_children():
		if child is VoiceSystem:
			return child
		var found = _find_voice_system(child)
		if found:
			return found
	return null

# ========== 核心方法 ==========
func type_text(text: String, callback: Callable = Callable()):
	if _is_typing:
		stop()
	
	_full_text = text
	_current_index = 0
	_callback = callback
	_is_typing = true
	_char_count_since_sound = 0
	
	if label:
		label.text = ""
	
	if voice_enabled and voice_system:
		var speed = voice_speed_multiplier * (1.0 + (1.0 / type_speed) * 0.1)
		speed = clamp(speed, 0.5, 2.0)
		voice_system.speak(text, speed)
	
	_timer.wait_time = type_speed
	_timer.start()
	
	if enable_sound and type_sound:
		type_sound.play()

func stop():
	_is_typing = false
	if _timer:
		_timer.stop()
	if label:
		label.text = _full_text
	if voice_system:
		voice_system.stop()

func skip():
	if not _is_typing:
		return
	
	_is_typing = false
	_timer.stop()
	
	if label:
		label.text = _full_text
	
	if voice_system:
		voice_system.stop()
	
	typing_finished.emit()
	
	if finish_sound:
		finish_sound.play()
	
	if _callback.is_valid():
		_callback.call()

func _on_timer_timeout():
	if _current_index < _full_text.length():
		_current_index += 1
		
		if label:
			label.text = _full_text.substr(0, _current_index)
		
		char_typed.emit(_full_text[_current_index - 1], _current_index - 1)
		
		if enable_sound and type_sound and not voice_enabled:
			_char_count_since_sound += 1
			if _char_count_since_sound >= type_sound_interval:
				type_sound.play()
				_char_count_since_sound = 0
	else:
		_is_typing = false
		_timer.stop()
		typing_finished.emit()
		
		if finish_sound:
			finish_sound.play()
		
		if _callback.is_valid():
			_callback.call()

func is_typing() -> bool:
	return _is_typing

func get_full_text() -> String:
	return _full_text

func get_current_text() -> String:
	return label.text if label else ""

func get_progress() -> float:
	if _full_text.length() == 0:
		return 0.0
	return float(_current_index) / float(_full_text.length())

func set_voice_enabled(enabled: bool):
	voice_enabled = enabled
	if not enabled and voice_system:
		voice_system.stop()

func set_type_speed(speed: float):
	type_speed = speed
