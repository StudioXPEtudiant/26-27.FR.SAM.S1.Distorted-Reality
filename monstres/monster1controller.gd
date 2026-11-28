
extends CharacterBody3D

# ==================================================
# MOVEMENT
# ==================================================

@export_group("Movement")
@export var move_speed := 3.0
@export var move_acceleration := 6.0
@export var turn_speed := 4.0
@export var stop_distance := 0.25

# ==================================================
# LEGS
# ==================================================

@export_group("Leg Placement")
@export var leg_spread := 1.5
@export var leg_length_offset := 1.3
@export var foot_reach := 1.5

# ==================================================
# LEG TIMING
# ==================================================

@export_group("Leg Timing")
@export var diagonal_step_delay := 0.25

var foot_last_snap := {}

# ==================================================
# BODY SUPPORT
# ==================================================

@export_group("Body Support")
@export var body_clearance := 1.2
@export var support_strength := 35.0
@export var support_damping := 12.0

# ==================================================
# GRAVITY
# ==================================================

@export_group("Gravity")
@export var gravity_strength := 12.0
@export var max_fall_speed := 3.0

# ==================================================
# GROUND DETECTION
# ==================================================

@export_group("Ground Detection")
@export var foot_ray_distance := 5.0
@export var foot_ray_start := 0.5
@export var foot_surface_offset := 0.06

@export_flags_3d_physics var ground_collision_mask := 0xFFFFFFFF

# ==================================================
# SURFACE
# ==================================================

@export_group("Surface")
@export var surface_check_distance := 3.0
@export var surface_alignment_speed := 4.0

# ==================================================
# NODES
# ==================================================

@onready var target = get_node_or_null("../Target")

@onready var feet = {
	"LF": $LF,
	"RF": $RF,
	"LB": $LB,
	"RB": $RB
}

# ==================================================
# VARIABLES
# ==================================================

var surface_normal := Vector3.UP
var forward := Vector3(0, 0, 1)

var normal_velocity := 0.0
var tangent_velocity := Vector3.ZERO

var foot_positions := {}
var foot_has_ground := {}


# ==================================================
# INITIALIZATION
# ==================================================

func _ready():

	var now = Time.get_ticks_msec()

	for key in feet:
		foot_positions[key] = feet[key].global_position
		foot_has_ground[key] = false
		foot_last_snap[key] = now

	initialize_feet()


func initialize_feet():

	for key in feet:

		var position = raycast_ground_at(
			get_initial_leg_anchor(key)
		)

		if position != null:
			foot_positions[key] = position
			foot_has_ground[key] = true
			feet[key].global_position = position

	foot_last_snap["LF"] = Time.get_ticks_msec()
	foot_last_snap["RB"] = Time.get_ticks_msec()


# ==================================================
# MAIN PHYSICS
# ==================================================

func _physics_process(delta):

	update_surface(delta)
	update_orientation(delta)
	update_body(delta)
	update_legs()


# ==================================================
# SURFACE DETECTION
# ==================================================

func update_surface(delta):

	var space = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(
		global_position,
		global_position - surface_normal * surface_check_distance
	)

	query.exclude = [get_rid()]
	query.collision_mask = ground_collision_mask

	var hit = space.intersect_ray(query)

	if hit:
		surface_normal = surface_normal.slerp(
			hit.normal,
			clamp(surface_alignment_speed * delta, 0.0, 1.0)
		).normalized()


# ==================================================
# ORIENTATION
# ==================================================

func update_orientation(delta):

	if target == null:
		return

	var direction = target.global_position - global_position
	direction = direction.slide(surface_normal)

	if direction.length() > stop_distance:

		direction = direction.normalized()

		forward = forward.slerp(
			direction,
			clamp(turn_speed * delta, 0.0, 1.0)
		).normalized()

	forward = forward.slide(surface_normal).normalized()

	if forward.length_squared() < 0.001:
		return

	var desired_basis = Basis.looking_at(
		forward,
		surface_normal,
		true
	)

	global_basis = global_basis.slerp(
		desired_basis,
		clamp(turn_speed * delta, 0.0, 1.0)
	).orthonormalized()


# ==================================================
# NORMAL LEG ANCHORS
# ==================================================

func get_leg_anchor(key: String) -> Vector3:

	var side := 1.0
	var front := 1.0

	match key:

		"LF":
			side = 1.0
			front = 1.0

		"RF":
			side = -1.0
			front = 1.0

		"LB":
			side = 1.0
			front = -1.0

		"RB":
			side = -1.0
			front = -1.0

	var local_offset = Vector3(
		side * leg_spread,
		0.0,
		front * leg_length_offset
	)

	return global_transform * local_offset


# ==================================================
# INITIAL LEG POSITIONS
# ==================================================

func get_initial_leg_anchor(key: String) -> Vector3:

	var side := 1.0
	var front := 1.0

	match key:

		"LF":
			side = 1.0
			front = 1.0

		"RF":
			side = -1.0
			front = -1.0

		"LB":
			side = 1.0
			front = 1.0

		"RB":
			side = -1.0
			front = -1.0

	var local_offset = Vector3(
		side * leg_spread,
		0.0,
		front * leg_length_offset
	)

	return global_transform * local_offset


# ==================================================
# NORMAL FOOT LANDING POSITION
# ==================================================

func get_step_position(key: String) -> Vector3:

	return get_leg_anchor(key)


# ==================================================
# GROUND RAYCAST
# ==================================================

func raycast_ground_at(origin: Vector3) -> Variant:

	var space = get_world_3d().direct_space_state

	var query = PhysicsRayQueryParameters3D.create(
		origin + surface_normal * foot_ray_start,
		origin - surface_normal * foot_ray_distance
	)

	query.exclude = [get_rid()]
	query.collision_mask = ground_collision_mask

	var hit = space.intersect_ray(query)

	if hit.is_empty():
		return null

	return hit.position + hit.normal * foot_surface_offset


func get_ground_position(key: String) -> Variant:

	return raycast_ground_at(get_leg_anchor(key))


# ==================================================
# FOOT REPOSITIONING AND TIMING
# ==================================================

func update_legs():

	var now = Time.get_ticks_msec()

	for key in feet:

		var anchor = get_leg_anchor(key)

		var distance = foot_positions[key].distance_to(anchor)

		if not foot_has_ground[key] or distance > foot_reach:

			var previous_leg := ""

			# RF must wait for LF.
			# LB must wait for RB.
			match key:

				"RF":
					previous_leg = "LF"

				"LB":
					previous_leg = "RB"

			# Minimum delay.
			if previous_leg != "":

				var elapsed = (
					now - foot_last_snap[previous_leg]
				) / 1000.0

				if elapsed < diagonal_step_delay:
					feet[key].global_position = foot_positions[key]
					continue

			var ground = raycast_ground_at(
				get_step_position(key)
			)

			if ground == null:
				continue

			# Instant snap.
			foot_positions[key] = ground
			foot_has_ground[key] = true

			foot_last_snap[key] = now

		# Keep FABRIK target planted.
		feet[key].global_position = foot_positions[key]


# ==================================================
# BODY MOVEMENT AND GRAVITY
# ==================================================

func update_body(delta):

	var desired_velocity := Vector3.ZERO

	if target != null:

		var direction = target.global_position - global_position
		direction = direction.slide(surface_normal)

		if direction.length() > stop_distance:

			desired_velocity = direction.normalized() * move_speed

	tangent_velocity = tangent_velocity.move_toward(
		desired_velocity,
		move_acceleration * delta
	)

	# Gravity.
	var gravity = -gravity_strength

	# Support from planted feet.
	var average_position := Vector3.ZERO
	var count := 0

	for key in feet:

		if not foot_has_ground[key]:
			continue

		average_position += foot_positions[key]
		count += 1

	var support := 0.0

	if count > 0:

		average_position /= count

		var height = (
			global_position - average_position
		).dot(surface_normal)

		var error = body_clearance - height

		support = (
			maxf(error, 0.0) * support_strength
			- normal_velocity * support_damping
		)

	normal_velocity += (gravity + support) * delta

	normal_velocity = clamp(
		normal_velocity,
		-max_fall_speed,
		max_fall_speed
	)

	velocity = (
		tangent_velocity +
		surface_normal * normal_velocity
	)

	var collision = move_and_collide(velocity * delta)

	if collision:

		var normal = collision.get_normal()

		velocity = velocity.slide(normal)

		normal_velocity = velocity.dot(surface_normal)
		tangent_velocity = velocity.slide(surface_normal)
