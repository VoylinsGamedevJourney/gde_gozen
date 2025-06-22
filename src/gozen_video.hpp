#pragma once

#include <cstdint>
#include <cmath>

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/time.hpp>
#include <godot_cpp/classes/os.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/classes/gd_extension_manager.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#include "ffmpeg.hpp"
#include "ffmpeg_helpers.hpp"


using namespace godot;

class GoZenVideo : public Resource {
	GDCLASS(GoZenVideo, Resource);

private:
	// FFmpeg classes
	UniqueAVFormatCtxInput av_format_ctx;
	UniqueAVCodecCtx av_codec_ctx = nullptr;
	AVStream *av_stream = nullptr;

	UniqueAVPacket av_packet;
	UniqueAVFrame av_frame;
	UniqueAVFrame av_sws_frame;
	UniqueSwsCtx sws_ctx;

	enum AVColorPrimaries color_profile;

	// Default variable types
	int response = 0;
	int padding = 0;

	int8_t rotation = 0;
	int8_t interlaced = 0; // 0 = no interlacing, 1 = interlaced top first, 2 interlaced bottom first
	
	int64_t duration = 0;
	int64_t frame_count = 0;

	int64_t start_time_video = 0;
	int64_t frame_timestamp = 0;
	int64_t current_pts = 0;

	double average_frame_duration = 0;
	double stream_time_base_video = 0;

	float framerate = 0.;

	bool loaded = false; // Is true after open()
	bool debug = false;
	bool using_sws = false; // This is set for when the pixel format is foreign and not directly supported by the addon
	bool full_color_range = true;

	// Godot classes
	String path = "";
	String pixel_format = "";

	Vector2i resolution = Vector2i(0, 0);

	AudioStreamWAV *audio = nullptr;

	Ref<Image> y_data;
	Ref<Image> u_data;
	Ref<Image> v_data;


	// Private functions
	void _copy_frame_data();
	void _clean_frame_data();

	int _seek_frame(int a_frame_nr);

	inline void _log(String message) {
		if (debug)
			UtilityFunctions::print("GoZenVideo: ", message, ".");
	}
	inline bool _log_err(String message) {
		UtilityFunctions::printerr("GoZenVideo: ", message, "!");
		return false;
	}

public:
	GoZenVideo() {}
	~GoZenVideo() { close(); }

	static Dictionary get_file_meta(String a_file_path);

	int open(const String& a_path);
	void close();

	inline bool is_open() { return loaded; }

	int seek_frame(int a_frame_nr);
	bool next_frame(bool a_skip = false);

	inline Ref<AudioStreamWAV> get_audio() { return audio; };

	inline String get_path() { return path; }

	inline float get_framerate() { return framerate; }
	inline int get_frame_count() { return std::round(frame_count); };
	inline Vector2i get_resolution() { return resolution; }
	inline int get_width() { return resolution.x; }
	inline int get_height() { return resolution.y; }
	inline int get_padding() { return padding; }
	inline int get_rotation() { return rotation; }

	inline void enable_debug() { av_log_set_level(AV_LOG_VERBOSE); debug = true; }
	inline void disable_debug() { av_log_set_level(AV_LOG_INFO); debug = false; }
	inline bool get_debug_enabled() { return debug; }

	inline String get_pixel_format() { return pixel_format; }
	inline String get_color_profile() { return av_color_primaries_name(color_profile); }

	inline bool is_full_color_range() { return full_color_range; }

	inline Ref<Image> get_y_data() { return y_data; }
	inline Ref<Image> get_u_data() { return u_data; }
	inline Ref<Image> get_v_data() { return v_data; }


protected:
	static void _bind_methods();
};
