extends Node

const WIDTH := 1152
const HEIGHT := 648
const NUM_AGENTS := 10000000

var rd: RenderingDevice
var agent_shader: RID
var diffuse_shader: RID
var agent_pipeline: RID
var diffuse_pipeline: RID
var agent_buffer: RID
var trail_map: RID
var display_image: RID
var agent_uniform_set: RID
var diffuse_uniform_set: RID
var output_texture: ImageTexture
var time := 0.0

func _ready() -> void:
	_setup()

func _process(delta: float) -> void:
	time += delta
	_dispatch_agents(delta)
	_dispatch_diffuse(delta)
	_read_back()

func _setup() -> void:
	rd = RenderingServer.create_local_rendering_device()

	# --- Shaders ---
	agent_shader = _load_shader("res://agent.glsl")
	diffuse_shader = _load_shader("res://diffuseEvaporate.glsl")

	# --- Agent buffer ---
	var agents := PackedFloat32Array()
	for i in NUM_AGENTS:
		# Spawn agents in a circle in the center
		var angle := randf() * TAU
		var radius := randf() * 200.0
		agents.append(WIDTH / 2.0 + cos(angle) * radius)  # pos.x
		agents.append(HEIGHT / 2.0 + sin(angle) * radius) # pos.y
		agents.append(angle + PI)                          # face outward
		agents.append(0.0)                                 # species/pad
	agent_buffer = rd.storage_buffer_create(
		agents.size() * 4, agents.to_byte_array()
	)

	# --- Textures ---
	trail_map = _create_texture(WIDTH, HEIGHT,
		RenderingDevice.DATA_FORMAT_R32_SFLOAT,
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)
	display_image = _create_texture(WIDTH, HEIGHT,
		RenderingDevice.DATA_FORMAT_R8G8B8A8_UNORM,
		RenderingDevice.TEXTURE_USAGE_STORAGE_BIT |
		RenderingDevice.TEXTURE_USAGE_CAN_COPY_FROM_BIT
	)

	# --- Uniform sets ---
	agent_uniform_set = _create_uniform_set(agent_shader, [
		_storage_buffer_uniform(agent_buffer, 0),
		_image_uniform(trail_map, 1),
	])
	diffuse_uniform_set = _create_uniform_set(diffuse_shader, [
		_image_uniform(trail_map, 0),
		_image_uniform(display_image, 1),
	])

	# --- Pipelines ---
	agent_pipeline = rd.compute_pipeline_create(agent_shader)
	diffuse_pipeline = rd.compute_pipeline_create(diffuse_shader)

	# --- Display ---
	var placeholder := Image.create(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8)
	output_texture = ImageTexture.create_from_image(placeholder)
	$TextureRect.texture = output_texture

func _dispatch_agents(delta: float) -> void:
	var push := PackedFloat32Array([
		time, delta, float(WIDTH), float(HEIGHT),
		75.0,          # move_speed
		60.0,            # turn_speed
		.3,            # sensor_angle
		10,           # sensor_dist
		5.0,            # sensor_size
		0.01,            # deposit_amount
		float(NUM_AGENTS),  # ← agent_count
		0.0             # pad
	])
	var groups := int(ceil(float(NUM_AGENTS) / 64.0))
	_dispatch(agent_pipeline, agent_uniform_set, push, groups, 1, 1)

func _dispatch_diffuse(delta: float) -> void:
	var push := PackedFloat32Array([
	.1, #lower = trails last longer
	0, #lower = trails spread less
	delta, 
	0.0
	])
	
	
	var gx := int(ceil(float(WIDTH) / 8.0))
	var gy := int(ceil(float(HEIGHT) / 8.0))
	_dispatch(diffuse_pipeline, diffuse_uniform_set, push, gx, gy, 1)

func _dispatch(pipeline, uniform_set, push: PackedFloat32Array, gx, gy, gz) -> void:
	var push_bytes := push.to_byte_array()
	var compute_list := rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(compute_list, pipeline)
	rd.compute_list_bind_uniform_set(compute_list, uniform_set, 0)
	rd.compute_list_set_push_constant(compute_list, push_bytes, push_bytes.size())
	rd.compute_list_dispatch(compute_list, gx, gy, gz)
	rd.compute_list_end()
	rd.submit()
	rd.sync()

func _read_back() -> void:
	var raw := rd.texture_get_data(display_image, 0)
	var img := Image.create_from_data(WIDTH, HEIGHT, false, Image.FORMAT_RGBA8, raw)
	output_texture.update(img)

# --- Helpers ---

func _load_shader(path: String) -> RID:
	var file := load(path)
	var spirv: RDShaderSPIRV = file.get_spirv()
	if spirv.compile_error_compute != "":
		push_error("Shader error in " + path + ": " + spirv.compile_error_compute)
	return rd.shader_create_from_spirv(spirv)

func _create_texture(w: int, h: int, format: int, usage: int) -> RID:
	var fmt := RDTextureFormat.new()
	fmt.width = w
	fmt.height = h
	fmt.format = format
	fmt.usage_bits = usage
	return rd.texture_create(fmt, RDTextureView.new(), [])

func _storage_buffer_uniform(buffer: RID, binding: int) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	u.binding = binding
	u.add_id(buffer)
	return u

func _image_uniform(texture: RID, binding: int) -> RDUniform:
	var u := RDUniform.new()
	u.uniform_type = RenderingDevice.UNIFORM_TYPE_IMAGE
	u.binding = binding
	u.add_id(texture)
	return u

func _create_uniform_set(shader: RID, uniforms: Array) -> RID:
	return rd.uniform_set_create(uniforms, shader, 0)

func _notification(what: int) -> void:
	if what == NOTIFICATION_PREDELETE:
		rd.free_rid(agent_uniform_set)
		rd.free_rid(diffuse_uniform_set)
		rd.free_rid(agent_buffer)
		rd.free_rid(trail_map)
		rd.free_rid(display_image)
		rd.free_rid(agent_pipeline)
		rd.free_rid(diffuse_pipeline)
		rd.free_rid(agent_shader)
		rd.free_rid(diffuse_shader)
		rd.free()
