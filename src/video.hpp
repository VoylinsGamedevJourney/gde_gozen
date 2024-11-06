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

#include "ffmpeg_includes.hpp"


using namespace godot;

class Video : public Resource {
	GDCLASS(Video, Resource);

private:
	// FFmpeg classes
	AVFormatContext *av_format_ctx = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr;
	AVBufferRef *hw_device_ctx = nullptr;
	AVStream *av_stream_video = nullptr;

	AVFrame *av_frame = nullptr;
	AVFrame *av_hw_frame = nullptr;
	AVPacket *av_packet = nullptr;

	enum AVHWDeviceType hw_decoder;
	enum AVPixelFormat hw_pix_fmt = AV_PIX_FMT_NONE;

	// Default variable types
	int response = 0;

	int8_t interlaced = 0; // 0 = no interlacing, 1 = interlaced top first, 2 interlaced bottom first
	
	int64_t duration = 0;
	int64_t frame_duration = 0;

	long start_time_video = 0;
	long frame_timestamp = 0;
	long current_pts = 0;

	double actual_pts = 0.;
	double expected_pts = 0.;
	double average_frame_duration = 0;
	double stream_time_base_video = 0;

	float framerate = 0.;

	bool loaded = false; // Is true after open()
	bool hw_decoding = true; // Set by user
	bool debug = false;

	std::string path = "";
	std::string pixel_format = "";
	std::string prefered_hw_decoder = "";

	// Godot classes
	Vector2i resolution = Vector2i(0, 0);

	AudioStreamWAV *audio = nullptr;

	PackedByteArray byte_array;
	PackedByteArray y_data;
	PackedByteArray u_data;
	PackedByteArray v_data;


	// Private functions
	static enum AVPixelFormat _get_format(AVCodecContext *a_av_ctx, const enum AVPixelFormat *a_pix_fmt);
	

	void _get_frame(AVCodecContext *a_codec_ctx, int a_stream_id);
	void _get_frame_audio(AVCodecContext *a_codec_ctx, int a_stream_id, AVFrame *a_frame, AVPacket *a_packet);
	void _copy_frame_data();
	void _clean_frame_data();

	const AVCodec *_get_hw_codec();
    enum AVPixelFormat _get_hw_format(const enum AVPixelFormat *a_pix_fmt);

	void _print_debug(std::string a_text);
	void _printerr_debug(std::string a_text);


public:
	Video() {}
	~Video() { close(); }

	static Dictionary get_file_meta(String a_file_path);
	static PackedStringArray get_available_hw_devices();

	int open(String a_path = "", bool a_load_audio = true);
	void close();

	inline bool is_open() { return loaded; }

	bool seek_frame(int a_frame_nr);
	bool next_frame(bool a_skip = false);

	inline Ref<AudioStreamWAV> get_audio() { return audio; };
	int _get_audio(AVStream* a_stream_audio);

	inline float get_framerate() { return framerate; }

	inline int get_frame_duration() { return frame_duration; };

	inline String get_path() { return path.c_str(); }

	inline Vector2i get_resolution() { return resolution; }
	inline int get_width() { return resolution.x; }
	inline int get_height() { return resolution.y; }

	inline void set_hw_decoding(bool a_value) {
		if (loaded)
			UtilityFunctions::printerr("Setting hw_decoding after opening file has no effect!");
		hw_decoding = a_value; }
	inline bool get_hw_decoding() { return hw_decoding; }

	inline void set_prefered_hw_decoder(String a_value) {
		if (loaded)
			UtilityFunctions::printerr("Setting prefered_hw_decoder after opening file has no effect!");
		prefered_hw_decoder = a_value.utf8(); }
	inline String get_prefered_hw_decoder() { return prefered_hw_decoder.c_str(); }

	inline void enable_debug() { av_log_set_level(AV_LOG_VERBOSE); debug = true; }
	inline void disable_debug() { debug = false; }
	inline bool get_debug_enabled() { return debug; }

	inline String get_pixel_format() { return pixel_format.c_str(); }

	inline PackedByteArray get_y_data() { return y_data; }
	inline PackedByteArray get_u_data() { return u_data; }
	inline PackedByteArray get_v_data() { return v_data; }

	void print_av_error(const char *a_message);


protected:
	static inline void _bind_methods() {
		ClassDB::bind_static_method("Video", D_METHOD("get_file_meta", "a_file_path"), &Video::get_file_meta);
		ClassDB::bind_static_method("Video", D_METHOD("get_available_hw_devices"), &Video::get_available_hw_devices);

		ClassDB::bind_method(D_METHOD("open", "a_path", "a_load_audio"), &Video::open, DEFVAL(""), DEFVAL(true));

		ClassDB::bind_method(D_METHOD("is_open"), &Video::is_open);

		ClassDB::bind_method(D_METHOD("seek_frame", "a_frame_nr"), &Video::seek_frame);
		ClassDB::bind_method(D_METHOD("next_frame", "a_skip"), &Video::next_frame, DEFVAL(false));
		ClassDB::bind_method(D_METHOD("get_audio"), &Video::get_audio);

		ClassDB::bind_method(D_METHOD("get_framerate"), &Video::get_framerate);

		ClassDB::bind_method(D_METHOD("get_path"), &Video::get_path);

		ClassDB::bind_method(D_METHOD("get_resolution"), &Video::get_resolution);
		ClassDB::bind_method(D_METHOD("get_width"), &Video::get_width);
		ClassDB::bind_method(D_METHOD("get_height"), &Video::get_height);

		ClassDB::bind_method(D_METHOD("get_frame_duration"), &Video::get_frame_duration);

		ClassDB::bind_method(D_METHOD("set_hw_decoding", "a_value"), &Video::set_hw_decoding);
		ClassDB::bind_method(D_METHOD("get_hw_decoding"), &Video::set_hw_decoding);

		ClassDB::bind_method(D_METHOD("set_prefered_hw_decoder", "a_codec"), &Video::set_prefered_hw_decoder);
		ClassDB::bind_method(D_METHOD("get_prefered_hw_decoder"), &Video::get_prefered_hw_decoder);

		ClassDB::bind_method(D_METHOD("enable_debug"), &Video::enable_debug);
		ClassDB::bind_method(D_METHOD("disable_debug"), &Video::disable_debug);
		ClassDB::bind_method(D_METHOD("get_debug_enabled"), &Video::get_debug_enabled);

		ClassDB::bind_method(D_METHOD("get_pixel_format"), &Video::get_pixel_format);

		ClassDB::bind_method(D_METHOD("get_y_data"), &Video::get_y_data);
		ClassDB::bind_method(D_METHOD("get_u_data"), &Video::get_u_data);
		ClassDB::bind_method(D_METHOD("get_v_data"), &Video::get_v_data);
	}
};
