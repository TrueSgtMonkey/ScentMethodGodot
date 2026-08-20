extends CharacterBody3D

const HEIGHT_CHECK: float = 0.25

enum ActionState {
	IDLE,
	CHASE
}
var action_state: int = ActionState.IDLE

@export var speed: float = 1.0
@export var jump_speed: float = 4.5
@export var sight_range: float = 25.0
@export var is_debug: bool = true

@onready var collision_shape       = $CollisionShape3D
@onready var enemy_mesh            = $EnemyMesh
@onready var forward_facing_mesh   = $ForwardFacingMesh
@onready var look_at_timer         = $LookAtTimer
@onready var bounce_timer          = $BounceTimer
@onready var jump_timer            = $JumpTimer
@onready var wall_timer            = $WallTimer
@onready var idle_timer            = $IdleTimer
@onready var idle_look_at_target   = $IdleLookAtTarget
@onready var ray_shot_timer        = $RayShotTimer
@onready var look_for_player_timer = $LookForPlayerTimer
@onready var spotted_player_timer  = $SpottedPlayerTimer

# state variables
var is_bounced: bool = false
var can_jump: bool = true
var gravity: float = 1.0
var is_currently_on_wall: bool = false
var is_look_at_on: bool = true
var is_ray_shot_ready: bool = true
var ray_shot_return: Dictionary = {}
var current_idle_direction: Vector3 = Vector3.ZERO
var is_look_for_player_active: bool = true
var is_player_spotted: bool = false

# reference variables
var chase_target_ref: Node3D = null

func _ready() -> void:
	# call this first to start idle timer
	change_state(ActionState.IDLE)
	gravity = ProjectSettings.get("physics/3d/default_gravity")
	look_at_timer.connect("timeout", enable_look_at)
	bounce_timer.connect("timeout", set_not_bounced)
	jump_timer.connect("timeout", set_can_jump)
	wall_timer.connect("timeout", set_not_on_wall)
	idle_timer.connect("timeout", idle_change_velocity)
	ray_shot_timer.connect("timeout", set_is_ray_shot_ready)
	look_for_player_timer.connect("timeout", set_is_look_for_player_active)
	spotted_player_timer.connect("timeout", unset_is_player_spotted)
	
	# TODO: Remove if enemy targets different nodes
	chase_target_ref = GlobalControl.player_ref

func _physics_process(delta: float) -> void:
	ray_shot_call_logic()
	if is_on_wall():
		is_currently_on_wall = true
		wall_timer.start()

	if !is_on_floor():
		velocity.y -= gravity * delta
	elif is_currently_on_wall && action_state != ActionState.IDLE:
		jump_if_available()
	else:
		velocity.y = 0.0

	perform_action_for_state()
	bounce_enemy_on_walls()
	move_and_slide()

func bounce_enemy_on_walls():
	if get_slide_collision_count() > 0 && is_on_wall():
		is_bounced = true
		bounce_timer.start()
		for slide in get_slide_collision_count():
			var collision: KinematicCollision3D = get_slide_collision(slide)
			bounce_based_on_action_state(collision)

func bounce_based_on_action_state(collision: KinematicCollision3D):
	var collision_normal: Vector3 = collision.get_normal()
	var previous_velocity: Vector3 = velocity
	
	match action_state:
		ActionState.IDLE:
			velocity = collision_normal * speed
			velocity.y = previous_velocity.y
			change_look_at_based_on_direction(collision_normal)
			idle_timer.start()
		ActionState.CHASE:
			velocity = Vector3(collision_normal.x, velocity.y, collision_normal.z) * speed

func jump_if_available():
	if !can_jump:
		velocity.y = 0.0
		return

	can_jump = false
	jump_timer.start()
	velocity.y = jump_speed

func change_state(next_action_state: int):
	action_state = next_action_state
	if action_state == ActionState.IDLE:
		idle_timer.start()
	else:
		idle_timer.stop()

func perform_action_for_state():
	match action_state:
		ActionState.IDLE:
			if is_target_found_with_timer():
				change_state(ActionState.CHASE)
				is_player_spotted = true
				spotted_player_timer.start()
		ActionState.CHASE:
			perform_look_at_with_timer(chase_target_ref)
			chase_target()
			if is_target_found_with_timer():
				is_player_spotted = true
				spotted_player_timer.start()
			if !is_player_spotted:
				change_state(ActionState.IDLE)

func is_target_found_with_timer() -> bool:
	if !is_look_for_player_active:
		return false

	is_look_for_player_active = false
	look_for_player_timer.start()
	return is_target_found()

func idle_change_velocity():
	var angle: float = randf() * 2.0 * PI
	current_idle_direction = Vector3(cos(angle), 0.0, sin(angle))
	velocity.x = current_idle_direction.x
	velocity.z = current_idle_direction.z
	change_look_at_based_on_direction(current_idle_direction)

func change_look_at_based_on_direction(direction: Vector3):
	idle_look_at_target.global_position = global_position + direction
	perform_look_at_target(idle_look_at_target)

func perform_look_at_with_timer(look_at_target: Node3D):
	if !is_look_at_on:
		return
	
	is_look_at_on = false
	look_at_timer.start()
	perform_look_at_target(look_at_target)

func chase_target():
	var previous_velocity: Vector3 = velocity
	if !is_bounced:
		velocity = (chase_target_ref.global_position - global_position).normalized() * speed
		velocity.y = previous_velocity.y

func enable_look_at():
	is_look_at_on = true

func perform_look_at_target(look_at_target: Node3D):
	if not is_instance_valid(look_at_target):
		return

	# TODO: add option to keep y rotation or not (for head?)
	# TODO: Keep horizontal only for body
	var previous_rotation: Vector3 = rotation
	look_at(look_at_target.global_position)
	rotation = Vector3(previous_rotation.x, rotation.y, previous_rotation.z)

func set_not_bounced():
	is_bounced = false
	
func set_can_jump():
	can_jump = true
	
func set_not_on_wall():
	is_currently_on_wall = false

func ray_shot_call_logic():
	if !is_ray_shot_ready:
		return

	is_ray_shot_ready = false
	ray_shot_timer.start()
	ray_shot_return = ray_shot(global_position, chase_target_ref.global_position)

func set_is_ray_shot_ready():
	is_ray_shot_ready = true

func ray_shot(pos1: Vector3, pos2: Vector3) -> Dictionary:
	var space_params: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.new()
	space_params.exclude = [self]
	space_params.from = pos1
	space_params.to = pos2
	return get_world_3d().direct_space_state.intersect_ray(space_params)

func is_target_found() -> bool:
	if ray_shot_return.size() == 0:
		return false
	
	# means that it cannot see the target
	if ray_shot_return.collider != chase_target_ref:
		return false
	
	var direction_to_target: Vector3 = (chase_target_ref.global_position - global_position)
	var facing_direction: Vector3 = (forward_facing_mesh.global_position - global_position).normalized()
	if direction_to_target.length() > sight_range:
		return false
	
	var dot_product: float = direction_to_target.normalized().dot(facing_direction)
	return (dot_product > 0)

func set_is_look_for_player_active():
	is_look_for_player_active = true
	
func unset_is_player_spotted():
	is_player_spotted = false
