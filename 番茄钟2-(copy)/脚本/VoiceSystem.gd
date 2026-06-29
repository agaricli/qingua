class_name VoiceSystem
extends Node

# ========== 导出参数 ==========
@export var enabled: bool = true
@export var pitch_base: float = 1.0
@export var pitch_variation: float = 0.15  # 随机音调变化范围
@export var speed_pitch_boost: float = 0.3  # 打字进度对音调的影响
@export var min_interval: float = 0.08  # 最小音节间隔
@export var max_interval: float = 0.18  # 最大音节间隔

# ========== 音频节点 ==========
var _audio_player: AudioStreamPlayer
var _audio_queue: Array = []  # 待播放音队列
var _is_playing: bool = false
var _timer: Timer
var _current_text: String = ""
var _current_index: int = 0
var _total_length: int = 0

# ========== 拼音到音节的映射表 ==========
# 注意：你需要把音节音频文件放在 res://sounds/voice/ 目录下
const SYLLABLE_MAP = {
	# 声母
	"b": "syllable_b",
	"p": "syllable_p",
	"m": "syllable_m",
	"f": "syllable_f",
	"d": "syllable_d",
	"t": "syllable_t",
	"n": "syllable_n",
	"l": "syllable_l",
	"g": "syllable_g",
	"k": "syllable_k",
	"h": "syllable_h",
	"j": "syllable_j",
	"q": "syllable_q",
	"x": "syllable_x",
	"zh": "syllable_zh",
	"ch": "syllable_ch",
	"sh": "syllable_sh",
	"r": "syllable_r",
	"z": "syllable_z",
	"c": "syllable_c",
	"s": "syllable_s",
	"y": "syllable_y",
	"w": "syllable_w",
	
	# 韵母
	"a": "syllable_a",
	"o": "syllable_o",
	"e": "syllable_e",
	"i": "syllable_i",
	"u": "syllable_u",
	"v": "syllable_v",  # ü
	"ai": "syllable_ai",
	"ei": "syllable_ei",
	"ui": "syllable_ui",
	"ao": "syllable_ao",
	"ou": "syllable_ou",
	"iu": "syllable_iu",
	"ie": "syllable_ie",
	"ve": "syllable_ve",
	"er": "syllable_er",
	"an": "syllable_an",
	"en": "syllable_en",
	"in": "syllable_in",
	"un": "syllable_un",
	"vn": "syllable_vn",
	"ang": "syllable_ang",
	"eng": "syllable_eng",
	"ing": "syllable_ing",
	"ong": "syllable_ong",
}

# ========== 特殊字符处理 ==========
const PUNCTUATION_MAP = {
	".": "syllable_pause",
	"!": "syllable_pause",
	"?": "syllable_pause",
	"，": "syllable_pause",
	"。": "syllable_pause",
	"！": "syllable_pause",
	"？": "syllable_pause",
	"、": "syllable_pause",
	"…": "syllable_pause",
	" ": "syllable_pause",
}

func _ready():
	_audio_player = AudioStreamPlayer.new()
	_audio_player.bus = "SFX"  # 确保有这个音频总线
	add_child(_audio_player)
	
	_timer = Timer.new()
	_timer.one_shot = false
	_timer.timeout.connect(_process_queue)
	add_child(_timer)
	
	# 加载所有音节音频
	_load_syllables()

# ========== 加载音节音频 ==========
func _load_syllables():
	# 你需要提前把音频文件放到 res://sounds/voice/ 目录
	# 文件名格式：syllable_a.ogg, syllable_b.ogg, 等等
	var voice_dir = "res://sounds/voice/"
	
	# 检查目录是否存在
	if not DirAccess.dir_exists_absolute(voice_dir):
		print("⚠️ 语音目录不存在：", voice_dir)
		print("📁 请创建目录并将音节音频放入：", voice_dir)
		return
	
	# 注意：这里不主动加载，而是用的时候按需加载
	print("✅ 语音系统已初始化")

# ========== 核心：播放语音 ==========
func speak(text: String, speed: float = 1.0):
	if not enabled:
		return
	
	if text.is_empty():
		return
	
	# 清空队列
	_audio_queue.clear()
	_current_text = text
	_current_index = 0
	_total_length = text.length()
	
	# 将文本转换为音节序列
	var syllables = _text_to_syllables(text)
	
	if syllables.is_empty():
		print("⚠️ 没有可播放的音节")
		return
	
	# 创建音频队列
	for syllable in syllables:
		var audio = _get_syllable_audio(syllable)
		if audio:
			_audio_queue.append({
				"audio": audio,
				"delay": _calculate_delay(speed),
				"pitch": _calculate_pitch(speed)
			})
	
	# 开始播放
	if _audio_queue.size() > 0:
		_is_playing = true
		_process_queue()

# ========== 文字转音节 ==========
func _text_to_syllables(text: String) -> Array:
	var result = []
	var pinyin = text  # 这里需要中文转拼音，暂时用简单处理
	
	# 简单的字符分割（中文每个字单独处理）
	for char in text:
		if char in PUNCTUATION_MAP:
			result.append(PUNCTUATION_MAP[char])
		else:
			# 简单版：直接将字符作为音节名
			# 你可以在这里调用中文转拼音库
			result.append("syllable_" + char)
	
	return result

# ========== 获取音节音频 ==========
func _get_syllable_audio(syllable_name: String) -> AudioStream:
	# 按需加载音频
	var path = "res://sounds/voice/" + syllable_name + ".ogg"
	
	if ResourceLoader.exists(path):
		return load(path)
	else:
		# 如果找不到具体音节，使用默认的 "beep"
		var default_path = "res://sounds/voice/syllable_default.ogg"
		if ResourceLoader.exists(default_path):
			return load(default_path)
		else:
			# 如果连默认都没有，生成一个简单音效
			return _generate_simple_syllable()

# ========== 生成简单音节（备用方案） ==========
func _generate_simple_syllable() -> AudioStream:
	var generator = AudioStreamGenerator.new()
	generator.mix_rate = 44100
	generator.buffer_length = 0.1
	
	var playback = generator.play()
	
	# 生成一个短促的"嘀"声
	var samples = []
	var sample_count = int(44100 * 0.08)
	for i in range(sample_count):
		var t = float(i) / sample_count
		var freq = 440.0 + randf_range(-50, 50)
		var value = sin(2.0 * PI * freq * t) * exp(-t * 30)
		samples.append(value)
	
	# 这里需要把 samples 填充到 playback 中
	# 因为实现复杂，建议还是用音频文件
	
	return generator

# ========== 计算延迟 ==========
func _calculate_delay(speed: float) -> float:
	var progress = float(_current_index) / float(_total_length) if _total_length > 0 else 0.5
	# 进度越快，速度越快（音调越高、间隔越短）
	var speed_factor = 1.0 + progress * 0.5
	var base_interval = lerp(max_interval, min_interval, clamp(speed / 2.0, 0.0, 1.0))
	return base_interval / (speed * speed_factor)

# ========== 计算音调 ==========
func _calculate_pitch(speed: float) -> float:
	var progress = float(_current_index) / float(_total_length) if _total_length > 0 else 0.5
	var pitch_boost = progress * speed_pitch_boost
	var variation = randf_range(-pitch_variation, pitch_variation)
	return pitch_base * speed * (1.0 + pitch_boost + variation)

# ========== 处理队列 ==========
func _process_queue():
	if _audio_queue.is_empty():
		_is_playing = false
		return
	
	var item = _audio_queue.pop_front()
	_current_index += 1
	
	# 播放音频
	_audio_player.stream = item.audio
	_audio_player.pitch_scale = item.pitch
	_audio_player.play()
	
	# 设置下一个的延迟
	if not _audio_queue.is_empty():
		var next_delay = _audio_queue[0].delay
		_timer.wait_time = next_delay
		_timer.start()

# ========== 停止播放 ==========
func stop():
	_audio_queue.clear()
	_is_playing = false
	_timer.stop()
	_audio_player.stop()

# ========== 公共方法 ==========
func is_speaking() -> bool:
	return _is_playing or _audio_player.playing
