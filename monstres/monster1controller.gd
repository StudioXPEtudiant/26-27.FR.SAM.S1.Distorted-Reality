
extends CharacterBody3D

@export var move_speed: float = 3.0
@export var turn_speed: float = 5.0

@onready var target: Marker3D = $"../Target"

func _physics_process(delta):
	var direction = target.global_position - global_position
	direction.y = 0

	if direction.length() > 0.2:
		direction = direction.normalized()

		velocity.x = direction.x * move_speed
		velocity.z = direction.z * move_speed

		var desired_rotation = atan2(
			direction.x,
			direction.z
		)

		rotation.y = lerp_angle(
			rotation.y,
			desired_rotation,
			turn_speed * delta
		)
	else:
		velocity.x = 0
		velocity.z = 0

	move_and_slide()
