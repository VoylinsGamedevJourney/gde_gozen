#pragma once

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

#include "ffmpeg.hpp"


using namespace godot;

class Renderer : public Resource {
	GDCLASS(Renderer, Resource);

private:
	// FFmpeg classes
	AVFormatContext *av_format_ctx = nullptr;

	AVCodecContext *av_codec_ctx_video = nullptr;
	AVStream *av_stream_video = nullptr;
	AVPacket *av_packet_video = nullptr;
	AVFrame *av_frame_video = nullptr;

	AVCodecContext *av_codec_ctx_audio = nullptr;
	AVStream *av_stream_audio = nullptr;
	AVPacket *av_packet_audio = nullptr;
	AVFrame *av_frame_audio = nullptr;

	struct SwsContext *sws_ctx = nullptr;
	struct SwrContext *swr_ctx = nullptr;

	// Default variable types
	int video_codec = -1;
	int audio_codec = -1;
	int sample_rate = -1;
	
	int gop_size = 0;
	int bit_rate = 400000; 
	int h264_preset = 0;

	int response = 0;
	int frame_nr = 0;

	float framerate = 30.;

	bool renderer_open = false;
	bool audio_added = false;
	bool debug = true;
	
	// Godot classes
	String path = "";
	Vector2i resolution = Vector2i(1920, 1080);


public:
	Renderer() {};
	~Renderer();

	int open();
	inline int is_open() { return renderer_open; }

	int send_frame(Ref<Image> a_image);
	int send_audio(Ref<AudioStreamWAV> a_wav);

	int close();


	inline void enable_debug() { av_log_set_level(AV_LOG_VERBOSE); debug = true; }
	inline void disable_debug() { av_log_set_level(AV_LOG_INFO); debug = false; }
	inline bool get_debug() { return debug; }

	inline void set_path(String a_path) { path = a_path; }
	inline String get_path() { return path; }

	inline void set_resolution(Vector2i a_resolution) { resolution = a_resolution; }
	inline Vector2i get_resolution() { return resolution; }

	inline void set_framerate(float a_framerate) { framerate = a_framerate; }
	inline float get_framerate() { return framerate; }

	inline void set_bit_rate(int a_bit_rate) { bit_rate = a_bit_rate; }
	inline int get_bit_rate() { return bit_rate; }

	inline void set_gop_size(int a_gop_size) { gop_size = a_gop_size; }
	inline int get_gop_size() { return gop_size; }

	void _print_debug(std::string a_text);
	void _printerr_debug(std::string a_text);

protected:
	static inline void _bind_methods() {
		ClassDB::bind_method(D_METHOD("open"), &Renderer::open);
		ClassDB::bind_method(D_METHOD("is_open"), &Renderer::is_open);

		ClassDB::bind_method(D_METHOD("send_frame", "a_image"), &Renderer::send_frame);
		ClassDB::bind_method(D_METHOD("send_audio", "a_wav"), &Renderer::send_audio);

		ClassDB::bind_method(D_METHOD("close"), &Renderer::close);

		ClassDB::bind_method(D_METHOD("enable_debug"), &Renderer::enable_debug);
		ClassDB::bind_method(D_METHOD("disable_debug"), &Renderer::disable_debug);
		ClassDB::bind_method(D_METHOD("get_debug"), &Renderer::get_debug);

		ClassDB::bind_method(D_METHOD("set_path", "a_file_path"), &Renderer::set_path);
		ClassDB::bind_method(D_METHOD("get_path"), &Renderer::get_path);

		ClassDB::bind_method(D_METHOD("set_resolution", "a_resolution"), &Renderer::set_resolution);
		ClassDB::bind_method(D_METHOD("get_resolution"), &Renderer::get_resolution);

		ClassDB::bind_method(D_METHOD("set_framerate", "a_framerate"), &Renderer::set_framerate);
		ClassDB::bind_method(D_METHOD("get_framerate"), &Renderer::get_framerate);

		ClassDB::bind_method(D_METHOD("set_bit_rate", "a_bit_rate"), &Renderer::set_bit_rate);
		ClassDB::bind_method(D_METHOD("get_bit_rate"), &Renderer::get_bit_rate);

		ClassDB::bind_method(D_METHOD("set_gop_size", "a_gop_size"), &Renderer::set_gop_size);
		ClassDB::bind_method(D_METHOD("get_gop_size"), &Renderer::get_gop_size);
	}
};
