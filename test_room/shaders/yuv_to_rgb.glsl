#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// YUV Planes
layout(set = 0, binding = 0, std430) restrict buffer YData { uint data[]; } y_data;
layout(set = 1, binding = 0, std430) restrict buffer UData { uint data[]; } u_data;
layout(set = 2, binding = 0, std430) restrict buffer VData { uint data[]; } v_data;

// A binding to the buffer we create in our script
layout(set = 3, binding = 0, std430) buffer RGBData { uint data[]; } rgb_data;

// data
layout(set = 4, binding = 0) buffer Parameters {
    int width;
    int height;
} params;


uint get_8bit_from_uint(uint data, int index) {
    return (data >> (8 * index)) & 0xFF;
}

void main() {
	int x = int(gl_GlobalInvocationID.x);
	int y = int(gl_GlobalInvocationID.y);

	int y_index = y * params.width + x;
	int u_index = (y / 2) * (params.width / 2) + (x / 2);
	int v_index = (y / 2) * (params.width / 2) + (x / 2);
	uint Y = (y_data.data[y_index >> 2] >> (8 * (y_index & 3))) & 0xFF;
    uint U = (u_data.data[u_index >> 2] >> (8 * (u_index & 3))) & 0xFF;
    uint V = (v_data.data[v_index >> 2] >> (8 * (v_index & 3))) & 0xFF;
//	// Determine the 32-bit integer index and the byte within that 32-bit word
//    int y_word_index = y_index / 4;
//    int y_byte_offset = y_index % 4;
//    int u_word_index = u_index / 4;
//    int u_byte_offset = u_index % 4;
//    int v_word_index = v_index / 4;
//    int v_byte_offset = v_index % 4;
//
//    // Extract the appropriate 8-bit value from the 32-bit word
//    uint Y = get_8bit_from_uint(y_data.data[y_word_index], y_byte_offset);
//    uint U = get_8bit_from_uint(u_data.data[u_word_index], u_byte_offset);
//    uint V = get_8bit_from_uint(v_data.data[v_word_index], v_byte_offset);
	int C = int(Y) - 16;
	int D = int(U) - 128;
	int E = int(V) - 128;

	int R = clamp((298 * C + 409 * E + 128) >> 8, 0, 255);
	int G = clamp((298 * C - 100 * D - 208 * E + 128) >> 8, 0, 255);
	int B = clamp((298 * C + 516 * D + 128) >> 8, 0, 255);
	
	int rgb_index = (y * params.width + x) * 4;
	rgb_data.data[y_index] = R | (G << 8) | (B << 16) | (255 << 24);
}