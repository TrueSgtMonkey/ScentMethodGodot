extends CharacterBody3D

const HEIGHT_CHECK: float = 0.25

@export var speed: float = 1.0
@export var jump_speed: float = 4.5

@onready var collision_shape     = $CollisionShape3D
@onready var enemy_mesh          = $EnemyMesh
@onready var forward_facing_mesh = $ForwardFacingMesh
@onready var look_at_timer       = $LookAtTimer
@onready var bounce_timer        = $BounceTimer
@onready var jump_timer          = $JumpTimer
@onready var wall_timer          = $WallTimer

var is_bounced: bool = false
var can_jump: bool = true
var gravity: float = 1.0
var is_currently_on_wall: bool = false

func _ready() -> void:
	gravity = ProjectSettings.get("physics/3d/default_gravity")
	look_at_timer.connect("timeout", perform_look_at)
	look_at_timer.start()
	bounce_timer.connect("timeout", set_not_bounced)
	jump_timer.connect("timeout", set_can_jump)
	wall_timer.connect("timeout", set_not_on_wall)

func _physics_process(delta: float) -> void:
	if is_on_wall():
		is_currently_on_wall = true
		wall_timer.start()
		
	if !is_on_floor():
		velocity.y -= gravity * delta
	elif is_currently_on_wall:
		jump_if_available()
	else:
		velocity.y = 0.0
	
	move_enemy()
	if get_slide_collision_count() > 0 && is_on_wall():
		is_bounced = true
		bounce_timer.start()
		for slide in get_slide_collision_count():
			var collision: KinematicCollision3D = get_slide_collision(slide)
			var collision_normal: Vector3 = collision.get_normal()
			velocity = Vector3(collision_normal.x, velocity.y, collision_normal.z) * speed

	move_and_slide()

func jump_if_available():
	if !can_jump:
		velocity.y = 0.0
		return

	can_jump = false
	jump_timer.start()
	if (global_position.y + HEIGHT_CHECK) <= GlobalControl.player_ref.global_position.y:
		velocity.y = jump_speed

func move_enemy():
	var previous_velocity: Vector3 = velocity
	if !is_bounced:
		velocity = (GlobalControl.player_ref.global_position - global_position).normalized() * speed
		velocity.y = previous_velocity.y

func perform_look_at():
	# TODO: Need some way to set turn on look_at_timer outside of this function
	if not is_instance_valid(GlobalControl.player_ref):
		return

	var previous_rotation: Vector3 = rotation
	look_at(GlobalControl.player_ref.global_position)
	rotation = Vector3(previous_rotation.x, rotation.y + PI, previous_rotation.z)
	look_at_timer.start()
	
func set_not_bounced():
	is_bounced = false
	
func set_can_jump():
	can_jump = true
	
func set_not_on_wall():
	is_currently_on_wall = false
