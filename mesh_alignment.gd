extends MeshInstance3D

@onready var cam =  $"../XROrigin3D/XRCamera3D"


func _process(delta: float) -> void:
	position.x = cam.position.x
	position.z = cam.position.z
