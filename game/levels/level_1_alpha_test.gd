extends Node

signal exit_game
signal defeat

var meteorite_pool: Array[MeteoriteBlock] = []

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_PAUSABLE
	get_node("Pause Screen").position.y -= 30
	get_node("Pause Screen").hide()
	get_node("Pause Screen/Resume Button").pressed.connect(self.on_resume_button_pressed)
	get_node("Pause Screen/Exit Button").pressed.connect(self.on_exit_button_pressed)
	
	$Player.connect("defeated", self._on_defeat)
	$Player.connect("player_update_position", self._on_player_move)
	
	var projectile_node = $Player/projectile_spawner
	projectile_node.position.x = 0
	projectile_node.position.y = 0
	projectile_node.connect("projectile_spawned", self._on_projectile_spawner_projectile_spawned)
	
	$Player/player_camera/score.position = Vector2(-60,-60)
	Global.emit_current_score()
	Global.emit_level_score(Global.Level.LEVEL_1)

func _process(_delta: float) -> void:
	if $"Pause Timer".is_stopped() == true:
		if Input.is_action_pressed("pause"):
			print("P pressed during unpaused")
			Global.print_score_data()
			on_pause_button_pressed()
	
	#Pause screen follows player to that it's always in the screen when the player pauses
	#80 is the offset so that it stays in the center (half of 160, the screen size)
	get_node("Pause Screen").position.x = get_node("Player").position.x - 80


func _on_projectile_spawner_projectile_spawned(pos, init_speed, gravity_scale) -> void:
	var meteor_instance: RigidBody2D =  $Player/projectile_spawner.projectile.instantiate() as RigidBody2D
	add_child(meteor_instance)
	meteor_instance.global_position.x = pos
	meteorite_pool.append(MeteoriteBlock.new(meteor_instance, pos))
	meteor_instance.linear_velocity = init_speed * Vector2(0,1)
	meteor_instance.gravity_scale = gravity_scale
	meteor_instance.connect("on_meteor_deleted", self._on_meteor_deleted)
	
func on_pause_button_pressed() -> void:
	get_tree().paused = true
	$Player/player_camera/score.hide()
	$"Pause Screen".show()
	$"Pause Screen".play_pause_audio()
	$"Pause Screen/PauseTimer".start()
	$"Pause Screen/Resume Button".grab_focus()
	
func on_resume_button_pressed() -> void:
	$Player/player_camera/score.show()	
	$"Pause Screen".hide()
	get_tree().paused = false

func on_exit_button_pressed() -> void:
	print("Pressed exit button")
	get_tree().paused = false
	emit_signal("exit_game")

func _on_pause_screen_unpause() -> void:
	print("unpaused by pressing pause button")
	$Player/player_camera/score.show()		
	$"Pause Screen".play_resume_audio()
	$"Pause Timer".start()
	
func _on_defeat() -> void:
	Global.score.set_score_by_level(Global.Level.LEVEL_1)
	Global.score.set_current(0)
	await get_tree().create_timer(2.0).timeout
	emit_signal("defeat")
	
func _on_player_move(_position) -> void:
	Global.update_score_by_move(_position.x)
	var offset = int((160.0/2.0)*1.05)
	var to_delete: Array[MeteoriteBlock] = []
	var to_preserve: Array[MeteoriteBlock] = []
	for met in meteorite_pool:
		if (met.offset > _position.x + offset) or (met.offset < _position.x - offset):
			to_delete.push_back(met)
		else:
			to_preserve.push_back(met)
	for met in to_delete:
		if is_instance_valid(met.meteorite):
			met.meteorite.queue_free()
	meteorite_pool = to_preserve
		
func _on_meteor_deleted(meteor):
	if is_instance_valid(meteor):
		meteor.queue_free()
		var to_preserve: Array[MeteoriteBlock] = []
		for meteorite_block in meteorite_pool:
			if meteorite_block.meteorite != meteor:
				to_preserve.push_back(meteorite_block)
		meteorite_pool = to_preserve
	
class MeteoriteBlock:
	var meteorite: RigidBody2D
	var offset: int
	func _init(_meteorite: RigidBody2D, _offset: int):
		self.meteorite = _meteorite
		self.offset = _offset
