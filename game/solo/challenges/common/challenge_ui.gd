class_name ChallengeUI
extends CanvasLayer
## Интерфейс испытания.

var _reward_scene: PackedScene = load("uid://cghfpr0gbxb2e")
## Ссылка на [Challenge].
@onready var challenge: Challenge = get_parent()
@onready var _rewards_total: Label = %Rewards/Total/Count

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_WM_GO_BACK_REQUEST:
			($QuitDialog as Window).popup_centered()


## Показывает вступительную анимацию.
func show_intro() -> void:
	($Intro/AnimationPlayer as AnimationPlayer).play(&"intro")
	($Intro/AnimationPlayer as AnimationPlayer).advance(0.0) # костыль


## Показывает анимацию победы.
func show_victory() -> void:
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"victory")
	($Main/GameEnd as Label).text = "ПОБЕДА!"


## Показывает анимацию поражения.
func show_defeat() -> void:
	($Main/GameEnd/AnimationPlayer as AnimationPlayer).play(&"defeat")
	($Main/GameEnd as Label).text = "ПОРАЖЕНИЕ!"


## Показывает награды из словаря [param rewards]. В [param total] находится сумма полученных монет.
## Для подробностей см. [method Challenge._get_rewards].
func show_rewards(rewards: Dictionary[String, int], total: int) -> void:
	var current_coins: int = Globals.get_int("coins")
	_rewards_total.text = "%d (+%d)" % [current_coins, 0]
	
	($Main/RewardsPanel as CanvasItem).show()
	var tween: Tween = create_tween()
	tween.tween_property($Main/RewardsPanel as CanvasItem, ^":modulate", Color.WHITE, 0.5).from(
			Color.TRANSPARENT)
	
	for reason: String in rewards:
		var reward: HBoxContainer = _reward_scene.instantiate()
		(reward.get_node(^"Reason") as Label).text = reason
		(reward.get_node(^"Count") as Label).text = str(rewards[reason])
		reward.modulate = Color.TRANSPARENT
		%Rewards.add_child(reward)
		tween.tween_property(reward, ^":modulate", Color.WHITE, 0.4)
	
	(%Rewards/Total as CanvasItem).move_to_front()
	tween.tween_interval(0.4)
	tween.tween_method(func(val: int) -> void: 
		_rewards_total.text = "%d (+%d)" % [current_coins + val, val], 0, total, 1.0)
	tween.tween_interval(3.5)
	tween.tween_property($Main/RewardsPanel as CanvasItem, ^":modulate", Color.TRANSPARENT, 0.4)


func _on_pause_pressed() -> void:
	get_tree().paused = true
	($PauseDialog as Window).popup_centered()


func _on_resume_pressed() -> void:
	get_tree().paused = false
	($PauseDialog as Window).hide()


func _on_quit_pressed() -> void:
	get_tree().paused = false
	Globals.main.game.close()
