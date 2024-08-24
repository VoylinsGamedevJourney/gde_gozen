#[compute]
#version 450

// Invocations in the (x, y, z) dimension
layout(local_size_x = 8, local_size_y = 8, local_size_z = 1) in;

// YUV Planes
layout(set = 0, binding = 0, std430) restrict buffer YData { float data[]; } y_data;
layout(set = 1, binding = 0, std430) restrict buffer UData { float data[]; } u_data;
layout(set = 2, binding = 0, std430) restrict buffer VData { float data[]; } v_data;

// A binding to the buffer we create in our script
layout(set = 3, binding = 0, std430) buffer RGBData { int data[]; } rgb_data;


void main() {
	//rgb_data.data[gl_GlobalInvocationID.x] = int(gl_GlobalInvocationID.x);// y_data.data[0];
	uint index = gl_GlobalInvocationID.x + gl_GlobalInvocationID.y * gl_NumWorkGroups.x * gl_WorkGroupSize.x;
    rgb_data.data[index] = int(index);
}
