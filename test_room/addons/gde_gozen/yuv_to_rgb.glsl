#[compute]
#version 450

layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// YUV Planes
layout(set = 0, binding = 0, std430) restrict readonly buffer YData { uint data[]; } y_data;
layout(set = 1, binding = 0, std430) restrict readonly buffer UData { uint data[]; } u_data;
layout(set = 2, binding = 0, std430) restrict readonly buffer VData { uint data[]; } v_data;

// Width data
layout(set = 3, binding = 0) buffer Parameters {
	int width;
} params;

// RGBA Image
layout(set = 4, binding = 0, rgba8) uniform restrict writeonly image2D rgb_image;


void main() {
	int x = int(gl_GlobalInvocationID.x);
	int y = int(gl_GlobalInvocationID.y);

	int y_index = y * params.width + x;
	int u_index = (y / 2) * (params.width / 2) + (x / 2);
	int v_index = (y / 2) * (params.width / 2) + (x / 2);
	int Y = int((y_data.data[y_index >> 2] >> (8 * (y_index & 3))) & 0xFF) - 16;
    int U = int((u_data.data[u_index >> 2] >> (8 * (u_index & 3))) & 0xFF) - 128;
    int V = int((v_data.data[v_index >> 2] >> (8 * (v_index & 3))) & 0xFF) - 128;
	
	imageStore(rgb_image, ivec2(gl_GlobalInvocationID.xy), vec4(
			float(clamp((298 * Y + 409 * V + 128) >> 8, 0, 255)) / 255.0, 
			float(clamp((298 * Y - 100 * U - 208 * V + 128) >> 8, 0, 255)) / 255.0, 
			float(clamp((298 * Y + 516 * U + 128) >> 8, 0, 255)) / 255.0, 
			1.0));
}
