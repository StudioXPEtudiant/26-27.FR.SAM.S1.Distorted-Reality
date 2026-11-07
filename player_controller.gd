extends CharacterBody3D

@onready var left_controller: XRController3D = $XROrigin3D/Lhand
@onready var camera: XRCamera3D = $XROrigin3D/XRCamera3D

@export var speed: float = 3.0

func _ready() -> void:
	pass


func _physics_process(delta):
	var joystick: Vector2 = left_controller.get_vector2("primary")

	var forward = camera.global_transform.basis.z
	var right = camera.global_transform.basis.x
	forward.y = 0
	right.y = 0
	forward = forward.normalized()
	right = right.normalized()
	var direction = (right * joystick.x) + (forward * -joystick.y)
	
	velocity.x = direction.x * speed
	velocity.z = direction.z * speed
	
	if not is_on_floor():
		velocity += get_gravity() * delta
	

	move_and_slide()
