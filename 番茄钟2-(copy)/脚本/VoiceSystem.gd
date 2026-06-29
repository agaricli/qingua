class_name VoiceSystem
extends Node

# ========== 信号 ==========
signal speaking_started(text: String)
signal speaking_finished()
signal syllable_played(syllable: String, index: int)

# ========== 导出参数 ==========
@export var enabled: bool = true
@export var pitch_base: float = 1.0
@export var pitch_variation: float = 0.12
@export var speed_pitch_boost: float = 0.25
@export var min_interval: float = 0.06
@export var max_interval: float = 0.15
@export var volume_db: float = 0.0

# ========== 音频相关 ==========
var _audio_players: Array = []
var _audio_queue: Array = []
var _is_speaking: bool = false
var _timer: Timer
var _current_text: String = ""
var _current_index: int = 0
var _total_length: int = 0
var _current_player_index: int = 0

# ✅ 新增：防止重复播放
var _is_stopping: bool = false

# ========== 配置 ==========
var _syllable_cache: Dictionary = {}
var _voice_dir: String = "res://音频/打字机/"

# ========== 初始化 ==========
func _ready():
	for i in range(3):
		var player = AudioStreamPlayer.new()
		player.bus = "SFX"
		player.volume_db = volume_db
		add_child(player)
		_audio_players.append(player)
	
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_process_queue)
	add_child(_timer)

# ========== 核心方法 ==========
func speak(text: String, speed: float = 1.0):
	if not enabled:
		return
	if text.is_empty():
		return
	
	# ✅ 如果正在说话，立即停止并清空
	if _is_speaking or _audio_queue.size() > 0:
		_force_stop()
	
	# ✅ 重置状态
	_audio_queue.clear()
	_is_speaking = false
	_is_stopping = false
	_timer.stop()
	
	# 停止所有播放器
	for player in _audio_players:
		player.stop()
	
	_current_text = text
	_current_index = 0
	_total_length = text.length()
	
	var syllables = _text_to_vowels(text)
	
	if syllables.is_empty():
		return
	
	# 过滤掉 pause 音
	var valid_syllables = []
	for s in syllables:
		if s != "pause":
			valid_syllables.append(s)
	
	if valid_syllables.is_empty():
		return
	
	for syllable in valid_syllables:
		var audio = _get_vowel_audio(syllable)
		if audio:
			var delay = _calculate_delay(speed)
			var pitch = _calculate_pitch(speed)
			_audio_queue.append({
				"audio": audio,
				"delay": delay,
				"pitch": pitch,
				"syllable": syllable
			})
	
	if _audio_queue.size() > 0:
		_is_speaking = true
		speaking_started.emit(text)
		# ✅ 延迟一帧开始，确保状态完全重置
		call_deferred("_process_queue")

# ✅ 强制停止
func _force_stop():
	_is_speaking = false
	_is_stopping = true
	_timer.stop()
	for player in _audio_players:
		player.stop()
	_audio_queue.clear()

func stop():
	if _is_speaking or _audio_queue.size() > 0:
		_force_stop()
		speaking_finished.emit()

# ========== 处理队列 ==========
func _process_queue():
	# ✅ 如果正在停止，不处理
	if _is_stopping:
		return
	
	if _audio_queue.is_empty():
		_is_speaking = false
		speaking_finished.emit()
		return
	
	var item = _audio_queue.pop_front()
	_current_index += 1
	
	var player = _audio_players[_current_player_index]
	_current_player_index = (_current_player_index + 1) % _audio_players.size()
	
	# ✅ 检查播放器是否正在播放，如果在播放则跳过这个音
	if player.playing:
		# 把当前音放回队列前面
		_audio_queue.push_front(item)
		# 等待更短时间再试
		_timer.wait_time = 0.02
		_timer.start()
		return
	
	player.stream = item.audio
	player.pitch_scale = item.pitch
	player.play()
	
	syllable_played.emit(item.syllable, _current_index)
	
	if not _audio_queue.is_empty():
		var next_delay = _audio_queue[0].delay
		_timer.wait_time = next_delay
		_timer.start()

# ========== 文字转元音序列 ==========
func _text_to_vowels(text: String) -> Array:
	var result = []
	var chars = text.split("")
	
	for char in chars:
		if char == "":
			continue
		
		if char in ["，", "。", "！", "？", "、", "…", " ", ".", "!", "?"]:
			result.append("pause")
			continue
		
		var vowel = _char_to_vowel(char)
		result.append(vowel)
	
	return result

# ========== 字符转元音 ==========
func _char_to_vowel(char: String) -> String:
	var vowels = ["a", "e", "i", "o", "u", "A", "E", "I", "O", "U"]
	if char in vowels:
		return char.to_lower()
	
	var pinyin_map = {
		"啊": "a", "阿": "a", "哦": "o", "嗯": "e",
		"一": "i", "依": "i", "无": "u", "呜": "u"
	}
	
	if char in pinyin_map:
		return pinyin_map[char]
	
	if _is_chinese_char(char):
		var pinyin = _get_pinyin_first_letter(char)
		if pinyin in ["b", "p", "m", "f", "d", "t", "n", "l", "g", "k", "h"]:
			return "a"
		elif pinyin in ["j", "q", "x", "zh", "ch", "sh", "r", "z", "c", "s", "y", "w"]:
			return "e"
		else:
			return "a"
	
	if _is_letter(char):
		var lower = char.to_lower()
		if lower in ["a", "e", "i", "o", "u"]:
			return lower
		else:
			return "e"
	
	return "a"

func _is_letter(char: String) -> bool:
	var code = char.unicode_at(0)
	return (code >= 65 and code <= 90) or (code >= 97 and code <= 122)

# ========== 获取元音音频 ==========
func _get_vowel_audio(vowel: String) -> AudioStream:
	if vowel in _syllable_cache:
		return _syllable_cache[vowel]
	
	var path = _voice_dir + vowel + ".wav"
	
	if ResourceLoader.exists(path):
		var audio = load(path)
		_syllable_cache[vowel] = audio
		return audio
	
	var synthesized = _synthesize_vowel(vowel)
	_syllable_cache[vowel] = synthesized
	return synthesized

func _synthesize_vowel(vowel: String) -> AudioStream:
	var freq_map = {
		"a": 523.0, "e": 587.0, "i": 659.0,
		"o": 698.0, "u": 784.0, "pause": 0.0
	}
	
	var freq = freq_map.get(vowel, 440.0)
	
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 22050
	generator.buffer_length = 0.08
	
	var frames = int(generator.mix_rate * 0.06)
	var data = PackedFloat32Array()
	
	for i in range(frames):
		var t = float(i) / float(generator.mix_rate)
		var env = exp(-t * 35.0)
		var sample = sin(2.0 * PI * freq * t) * env * 0.4
		data.append(sample)
	
	return generator

func _is_chinese_char(char: String) -> bool:
	var code = char.unicode_at(0)
	return (code >= 0x4E00 and code <= 0x9FFF)

func _get_pinyin_first_letter(char: String) -> String:
	var pinyin_map = {
		"你": "n", "好": "h", "我": "w", "是": "s", "不": "b",
		"了": "l", "的": "d", "一": "y", "在": "z", "有": "y",
		"人": "r", "这": "z", "中": "z", "大": "d", "为": "w",
		"个": "g", "上": "s", "学": "x", "习": "x", "天": "t",
		"休": "x", "息": "x", "眼": "y", "睛": "j", "多": "d",
		"喝": "h", "水": "s", "记": "j", "忆": "y", "站": "z",
		"起": "q", "来": "l", "加": "j", "油": "y", "专": "z",
		"注": "z", "摸": "m", "头": "t", "看": "k", "书": "s",
		"吃": "c", "饭": "f", "走": "z", "神": "s", "话": "h",
		"劳": "l", "逸": "y", "结": "j", "合": "h", "视": "s",
		"力": "l", "手": "s", "机": "j", "动": "d", "鼓": "g",
		"励": "l", "今": "j", "打": "d", "算": "s", "放": "f",
		"弃": "q", "坚": "j", "持": "c"
	}
	return pinyin_map.get(char, "a")

func _calculate_delay(speed: float) -> float:
	if _total_length == 0:
		return max_interval
	
	var progress = float(_current_index) / float(_total_length)
	var speed_factor = 1.0 + progress * 0.3
	var base_interval = lerp(max_interval, min_interval, clamp(speed / 2.0, 0.0, 1.0))
	return base_interval / (speed * speed_factor)

func _calculate_pitch(speed: float) -> float:
	if _total_length == 0:
		return pitch_base
	
	var progress = float(_current_index) / float(_total_length)
	var pitch_boost = progress * speed_pitch_boost
	var variation = randf_range(-pitch_variation, pitch_variation)
	return pitch_base * speed * (1.0 + pitch_boost + variation)

# ========== 公共方法 ==========
func is_speaking() -> bool:
	for player in _audio_players:
		if player.playing:
			return true
	return _is_speaking

func get_progress() -> float:
	if _total_length == 0:
		return 0.0
	return float(_current_index) / float(_total_length)

func set_volume_db(db: float):
	volume_db = db
	for player in _audio_players:
		player.volume_db = db
