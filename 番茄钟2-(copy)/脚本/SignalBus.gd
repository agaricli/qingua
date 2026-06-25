# SignalBus.gd - 全局信号总线
extends Node

static var instance = null

# ========== 原有信号 ==========
signal petting_started()
signal petting_ended()
signal pet_dialog_triggered(message: String)

# ========== ✅ 新增：动画控制信号 ==========
signal anim_play_idle()      # 切换到待机动画
signal anim_play_work()      # 切换到工作动画

func _ready():
	instance = self
	print("✅ 信号总线已初始化")
