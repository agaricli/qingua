class_name Typewriter
extends Node

signal typing_finished()
signal char_typed(char: String, index: int)

@export var label: Label
@export var type_speed: float = 0.05
@export var enable_sound: bool = true

var _is_typing: bool = false
var _full_text: String = ""
var _current_index: int = 0
var _timer: Timer
var _callback: Callable

func _ready():
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_on_timer_timeout)
	add_child(_timer)

func type_text(text: String, callback: Callable = Callable()):
	if _is_typing:
		stop()
	
	_full_text = text
	_current_index = 0
	_callback = callback
	_is_typing = true
	
	if label:
		label.text = ""
	
	_timer.wait_time = type_speed
	_timer.start()
	
	if enable_sound:
		_play_sound()

func stop():
	_is_typing = false
	if _timer:
		_timer.stop()
	if label:
		label.text = _full_text

func skip():
	if not _is_typing:
		return
	_is_typing = false
	_timer.stop()
	if label:
		label.text = _full_text
	typing_finished.emit()
	if _callback.is_valid():
		_callback.call()

func _on_timer_timeout():
	if _current_index < _full_text.length():
		_current_index += 1
		if label:
			label.text = _full_text.substr(0, _current_index)
		char_typed.emit(_full_text[_current_index - 1], _current_index - 1)
		if enable_sound:
			_play_sound()
	else:
		_is_typing = false
		_timer.stop()
		typing_finished.emit()
		if _callback.is_valid():
			_callback.call()

func _play_sound():
	# TODO: 添加打字音效
	# 如果有 AudioStreamPlayer，可以在这里播放
	# 例如：$TypeSound.play()
	pass

func is_typing() -> bool:
	return _is_typing

func get_full_text() -> String:
	return _full_text

func get_current_text() -> String:
	return label.text if label else ""
