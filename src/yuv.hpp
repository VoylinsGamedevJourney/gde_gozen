#pragma once

#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/utility_functions.hpp>


using namespace godot;

class Yuv : public Object {
	GDCLASS(Yuv, Object);

public:
	inline static Ref<Image> yuv420p_to_rgb(uint8_t* a_yuv_data[8], int a_linesize[8], int a_width, int a_height) {
		Ref<Image> l_image = memnew(Image);
		PackedByteArray l_rgb_data = PackedByteArray();
		int l_frame_size = a_width * a_height;
		int l_uv_width = a_width / 2;
		int l_uv_height = a_height / 2;

		l_rgb_data.resize(l_frame_size * 3);

		uint8_t* y_plane = a_yuv_data[0];
		uint8_t* u_plane = a_yuv_data[1];
		uint8_t* v_plane = a_yuv_data[2];
		int y_stride = a_linesize[0];
		int u_stride = a_linesize[1];
		int v_stride = a_linesize[2];

		for (int l_y = 0; l_y < a_height; ++l_y) {
			for (int l_x = 0; l_x < a_width; ++l_x) {
				int l_y_index = l_y * y_stride + l_x;
				int l_u_index = (l_y / 2) * u_stride + (l_x / 2);
				int l_v_index = (l_y / 2) * v_stride + (l_x / 2);
				uint8_t l_Y = y_plane[l_y_index];
				uint8_t l_U = u_plane[l_u_index];
				uint8_t l_V = v_plane[l_v_index];
				int l_C = l_Y - 16;
				int l_D = l_U - 128;
				int l_E = l_V - 128;

				int l_R = UtilityFunctions::clamp((298 * l_C + 409 * l_E + 128) >> 8, 0, 255);
				int l_G = UtilityFunctions::clamp((298 * l_C - 100 * l_D - 208 * l_E + 128) >> 8, 0, 255);
				int l_B = UtilityFunctions::clamp((298 * l_C + 516 * l_D + 128) >> 8, 0, 255);

				int l_rgb_index = (l_y * a_width + l_x) * 3;
				l_rgb_data.set(l_rgb_index, l_R);
				l_rgb_data.set(l_rgb_index + 1, l_G);
				l_rgb_data.set(l_rgb_index + 2, l_B);
			}
		}

		l_image->set_data(a_width, a_height, 0, l_image->FORMAT_RGB8, l_rgb_data);
		return l_image;
	}


//	inline static void rgb_to_yuv420p(Ref<Image> a_image, int a_width, int a_height) {
//		PackedByteArray l_yuv_data = PackedByteArray();
//		int l_frame_size = a_width * a_height;
//		int l_uv_width = a_width / 2;
//		int l_uv_height = a_height / 2;
//	
//		l_yuv_data.resize(l_frame_size * 3 / 2);
//	
//		uint8_t* y_plane = l_yuv_data.size();
//		uint8_t* u_plane = l_yuv_data.size() + l_frame_size;
//		uint8_t* v_plane = l_yuv_data.size() + l_frame_size + (l_frame_size / 4);
//	
//		for (int l_y = 0; l_y < a_height; ++l_y) {
//			for (int l_x = 0; l_x < a_width; ++l_x) {
//				int rgb_index = (l_y * a_width + l_x) * 3;
//				uint8_t l_R = a_image->get_data()[rgb_index];
//				uint8_t l_G = a_image->get_data()[rgb_index + 1];
//				uint8_t l_B = a_image->get_data()[rgb_index + 2];
//	
//				uint8_t l_Y = UtilityFunctions::clamp(static_cast<int>(0.299 * R + 0.587 * G + 0.114 * B), 0, 255);
//				uint8_t l_U = UtilityFunctions::clamp(static_cast<int>(-0.14713 * R - 0.28886 * G + 0.436 * B + 128), 0, 255);
//				uint8_t l_V = UtilityFunctions::clamp(static_cast<int>(0.615 * R - 0.51499 * G - 0.10001 * B + 128), 0, 255);
//	
//				y_plane[y * a_width + x] = Y;
//	
//				if (y % 2 == 0 && x % 2 == 0) {
//					int uv_index = (y / 2) * uv_width + (x / 2);
//					u_plane[uv_index] = U;
//					v_plane[uv_index] = V;
//				}
//			}
//		}
//	}


protected:
	static inline void _bind_methods() {}
};

