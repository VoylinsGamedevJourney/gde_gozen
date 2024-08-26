@tool
class_name GoZenServer
extends EditorPlugin

static var rd: RenderingDevice = RenderingServer.create_local_rendering_device()
static var shader_file: RDShaderFile = preload("yuv_to_rgb.glsl")
static var shader_spirv: RDShaderSPIRV
static var shader: RID
static var pipeline: RID
static var running: bool = false


func _enter_tree() -> void:
	add_custom_type("VideoPlayback", "Control", preload("video_playback.gd"), preload("icon.svg"))


func _exit_tree() -> void:
	remove_custom_type("VideoPlayback")


static func startup() -> void:
	if running:
		return
	shader_spirv = shader_file.get_spirv()
	shader = rd.shader_create_from_spirv(shader_spirv)
	pipeline = rd.compute_pipeline_create(shader)
	running = true


static func shutdown() -> void:
	if rd.compute_pipeline_is_valid(pipeline):
		rd.free_rid(pipeline)
	running = false


static func create_storage_buffer(a_data: PackedByteArray) -> RID:
	return rd.storage_buffer_create(a_data.size(), a_data)


static func buffer_update(a_rid: RID, a_data: PackedByteArray) -> void:
	rd.buffer_update(a_rid, 0, a_data.size(), a_data)


static func create_uniform_storage_buffer(a_buffer: RID, a_set: int) -> RID:
	var l_uniform: RDUniform = RDUniform.new()
	l_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	l_uniform.binding = 0
	l_uniform.add_id(a_buffer)
	return rd.uniform_set_create([l_uniform], shader, a_set)


static func cl_begin() -> int:
	var id: int = rd.compute_list_begin()
	rd.compute_list_bind_compute_pipeline(id, pipeline)
	return id


static func cl_bind_uniform_set(a_cl_id: int, a_uniform_set: RID, a_set_id: int) -> void:
	rd.compute_list_bind_uniform_set(a_cl_id, a_uniform_set, a_set_id)


static func cl_submit(a_cl_id: int, a_x: int, a_y: int, a_z: int, a_sync: bool = true) -> void:
	rd.compute_list_dispatch(a_cl_id, ceili(a_x/16.0), ceili(a_y/16.0), a_z)
	rd.compute_list_end()
	rd.submit()
	if a_sync:
		rd.sync()
