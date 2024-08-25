extends Control


var video: Video


func _ready() -> void:
	video = Video.new()
	video.open_video("/storage/Youtube/02 - Gamedev Journey/videos/2024-08-15_14-23-54.mkv")
	#(%TR as TextureRect).get_texture().set_image(video.seek_frame(0))
	video.seek_frame(0)
	var v_size: Vector2i = video.get_size()
	set_frame(v_size.x, v_size.y, video.get_y(), video.get_u(), video.get_v())


func set_frame(a_width: int, a_height: int, a_y: PackedByteArray, a_u: PackedByteArray, a_v: PackedByteArray) -> void:
	var rgb: PackedByteArray = []
	rgb.resize(a_y.size()*4)

	a_y[0] = 100
	a_y[1] = 100
	a_y[2] = 100
	a_y[3] = 100
	a_y[4] = 100
	a_y[5] = 100

	var l_params: PackedByteArray = PackedInt32Array([a_width, a_height]).to_byte_array()

	var l_rendering_server: RenderingDevice= RenderingServer.create_local_rendering_device()
	var l_shader_file: RDShaderFile = load("res://shaders/yuv_to_rgb.glsl")
	var l_shader_spirv: RDShaderSPIRV = l_shader_file.get_spirv()
	var l_shader: RID = l_rendering_server.shader_create_from_spirv(l_shader_spirv)
	
	var l_y_buffer: RID = l_rendering_server.storage_buffer_create(a_y.size(), a_y)
	var l_u_buffer: RID = l_rendering_server.storage_buffer_create(a_u.size(), a_u)
	var l_v_buffer: RID = l_rendering_server.storage_buffer_create(a_v.size(), a_v)
	var l_rgb_buffer: RID = l_rendering_server.storage_buffer_create(rgb.size(), rgb)
	var l_params_buffer: RID = l_rendering_server.storage_buffer_create(l_params.size(), l_params)

	var l_y_uniform: RDUniform = RDUniform.new()
	l_y_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	l_y_uniform.binding = 0
	l_y_uniform.add_id(l_y_buffer)
	var l_y_uniform_set: RID = l_rendering_server.uniform_set_create([l_y_uniform], l_shader, 0)

	var l_u_uniform: RDUniform = RDUniform.new()
	l_u_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	l_u_uniform.binding = 0
	l_u_uniform.add_id(l_u_buffer)
	var l_u_uniform_set: RID = l_rendering_server.uniform_set_create([l_u_uniform], l_shader, 1)

	var l_v_uniform: RDUniform = RDUniform.new()
	l_v_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	l_v_uniform.binding = 0
	l_v_uniform.add_id(l_v_buffer)
	var l_v_uniform_set: RID = l_rendering_server.uniform_set_create([l_v_uniform], l_shader, 2)

	var l_rgb_uniform: RDUniform = RDUniform.new()
	l_rgb_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	l_rgb_uniform.binding = 0
	l_rgb_uniform.add_id(l_rgb_buffer)
	var l_rgb_uniform_set: RID = l_rendering_server.uniform_set_create([l_rgb_uniform], l_shader, 3)

	var l_params_uniform: RDUniform = RDUniform.new()
	l_params_uniform.uniform_type = RenderingDevice.UNIFORM_TYPE_STORAGE_BUFFER
	l_params_uniform.binding = 0
	l_params_uniform.add_id(l_params_buffer)
	var l_params_uniform_set: RID = l_rendering_server.uniform_set_create([l_params_uniform], l_shader, 4)

	var l_pipeline: RID = l_rendering_server.compute_pipeline_create(l_shader)
	var l_compute_list: int = l_rendering_server.compute_list_begin()
	l_rendering_server.compute_list_bind_compute_pipeline(l_compute_list, l_pipeline)

	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_y_uniform_set, 0)
	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_u_uniform_set, 1)
	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_v_uniform_set, 2)
	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_rgb_uniform_set, 3)
	l_rendering_server.compute_list_bind_uniform_set(l_compute_list, l_params_uniform_set, 4)

	l_rendering_server.compute_list_dispatch(l_compute_list, ceili(a_width/8.0), ceili(a_height/8.0), 1)
	l_rendering_server.compute_list_end()

	l_rendering_server.submit()
	l_rendering_server.sync()

	var l_output: PackedByteArray = l_rendering_server.buffer_get_data(l_rgb_buffer)
	print("output: ", l_output)
	print("output size: ", l_output.size())

	var l_image: Image = Image.create_from_data(a_width, a_height, false, Image.FORMAT_RGBA8, l_output)
	(%TR as TextureRect).get_texture().set_image(l_image)
