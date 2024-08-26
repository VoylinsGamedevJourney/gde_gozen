#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 16, local_size_y = 16, local_size_z = 1) in;

// YUV Planes
layout(set = 0, binding = 0, std430) restrict readonly buffer YData { uint data[]; } y_data;
layout(set = 1, binding = 0, std430) restrict readonly buffer UData { uint data[]; } u_data;
layout(set = 2, binding = 0, std430) restrict readonly buffer VData { uint data[]; } v_data;

// A binding to the buffer we create in our script
layout(set = 3, binding = 0, std430) restrict writeonly buffer RGBData { uint data[]; } rgb_data;

// data
layout(set = 4, binding = 0) buffer Parameters {
    int width;
    int height;
} params;



void main() {
	int x = int(gl_GlobalInvocationID.x);
	int y = int(gl_GlobalInvocationID.y);

	int y_index = y * params.width + x;
	int u_index = (y / 2) * (params.width / 2) + (x / 2);
	int v_index = (y / 2) * (params.width / 2) + (x / 2);
	uint Y = (y_data.data[y_index >> 2] >> (8 * (y_index & 3))) & 0xFF;
    uint U = (u_data.data[u_index >> 2] >> (8 * (u_index & 3))) & 0xFF;
    uint V = (v_data.data[v_index >> 2] >> (8 * (v_index & 3))) & 0xFF;
	int C = int(Y) - 16;
	int D = int(U) - 128;
	int E = int(V) - 128;

	int R = clamp((298 * C + 409 * E + 128) >> 8, 0, 255);
	int G = clamp((298 * C - 100 * D - 208 * E + 128) >> 8, 0, 255);
	int B = clamp((298 * C + 516 * D + 128) >> 8, 0, 255);
	
	rgb_data.data[y_index] = R | (G << 8) | (B << 16) | (255 << 24);
}
