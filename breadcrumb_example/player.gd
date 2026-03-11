extends CharacterBody3D

@export var move_speed: float = 3.5
@export var move_acceleration: float = 18.0
@export var move_deceleration: float = 36.0
@export var final_move_acceleration: float = 48.0
@export var move_jerk: float = 3.0
@export var jump_speed: float = 5.5
@export var mouse_sensitivity: float = 0.007

@onready var pivot_ref: Node3D = $Pivot
@onready var player_cam: Camera3D = $Pivot/PlayerCam
@onready var grounded_timer: Timer = $GroundedTimer

var gravity: float = 1.0
var is_grounded: bool = false
var current_move_inputs: int = 0
var original_move_acceleration: float = 0.0

func _ready() -> void:
	gravity = ProjectSettings.get("physics/3d/default_gravity")
	grounded_timer.connect("timeout", not_grounded)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	original_move_acceleration = move_acceleration

func _physics_process(delta: float) -> void:
	var intended_velocity: Vector3 = player_move_inputs().normalized() * move_speed
	var y_velocity: float = velocity.y
	if current_move_inputs > 0:
		velocity = velocity.move_toward(intended_velocity, move_acceleration * delta)
		move_acceleration = move_toward(move_acceleration, final_move_acceleration, move_jerk * delta)
	else:
		velocity = velocity.move_toward(Vector3.ZERO, move_deceleration * delta)
		move_acceleration = move_toward(move_acceleration, original_move_acceleration, move_jerk * delta)
	velocity.y = y_velocity
	
	if is_on_floor():
		is_grounded = true
		grounded_timer.start()
	else:
		velocity.y -= gravity * delta

	if is_grounded && Input.is_action_just_pressed("jump"):
		velocity.y = jump_speed
		

	move_and_slide()

func player_move_inputs() -> Vector3:
	current_move_inputs = 0
	var intended_velocity: Vector3 = Vector3.ZERO
	if Input.is_action_pressed("move_forward"):
		current_move_inputs += 1
		intended_velocity += -pivot_ref.global_transform.basis.z
	if Input.is_action_pressed("move_left"):
		current_move_inputs += 1
		intended_velocity += -pivot_ref.global_transform.basis.x
	if Input.is_action_pressed("move_right"):
		current_move_inputs += 1
		intended_velocity += pivot_ref.global_transform.basis.x
	if Input.is_action_pressed("move_backward"):
		current_move_inputs += 1
		intended_velocity += pivot_ref.global_transform.basis.z
		
	return intended_velocity

func not_grounded():
	is_grounded = false

func _input(event: InputEvent) -> void:
	if event.is_action_released("jump"):
		if velocity.y > 0.0:
			velocity.y *= 0.25

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		pivot_ref.rotate_y(mouse_sensitivity * -event.relative.x)
		player_cam.rotate_x(mouse_sensitivity * -event.relative.y)
