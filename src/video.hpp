#pragma once

#include <cstdint>
#include <cmath>
#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include "godot_cpp/classes/gd_extension_manager.hpp"

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavdevice/avdevice.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/channel_layout.h>
#include <libavutil/avutil.h>
#include <libavutil/dict.h>
#include <libavutil/imgutils.h>
#include <libavutil/opt.h>
#include <libavutil/pixdesc.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
#include <libavutil/error.h>
#include <libavutil/frame.h>
#include <libavutil/rational.h>
}

using namespace godot;

class Video : public Resource {
	GDCLASS(Video, Resource);

private:
	AVFormatContext *av_format_ctx = nullptr;
	AVStream *av_stream_video = nullptr, *av_stream_audio = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr;

	AVFrame *av_frame = nullptr;
	AVPacket *av_packet = nullptr;

	struct SwsContext *sws_ctx = nullptr;

	PackedByteArray byte_array; // Only for video frames

	int response = 0, src_linesize[4] = {0, 0, 0, 0}, total_frame_number = 0, video_width = 0;
	long start_time_video = 0, frame_timestamp = 0, current_pts = 0;
	double average_frame_duration = 0, stream_time_base_video = 0;

	AudioStreamWAV* audio = memnew(AudioStreamWAV);

	bool is_open = false, variable_framerate = false;
	int64_t video_duration = 0;
	int8_t interlaced = 0; // 0 = no interlacing, 1 = interlaced top first, 2 interlaced bottom first
	float framerate = 0.0;
	double expected_pts = 0.0, actual_pts = 0.0;

public:
	Video() {}
	~Video() { close_video(); }

	static Dictionary get_video_file_meta(String a_file_path);

	int open_video(String a_path = "", bool a_load_audio = true);
	void close_video();

	inline bool is_video_open() { return is_open; }

	Ref<Image> seek_frame(int a_frame_nr);
	Ref<Image> next_frame();

	inline Ref<AudioStreamWAV> get_audio() { return audio; };
	int _get_audio();

	inline float get_framerate() { return framerate; }

	inline bool is_framerate_variable() { return variable_framerate; }
	inline int get_total_frame_nr() { return total_frame_number; };

	void print_av_error(const char *a_message);

	void _get_frame(AVCodecContext *a_codec_ctx, int a_stream_id);
	void _decode_video_frame(Ref<Image> a_image);

protected:
	static inline void _bind_methods() {
		ClassDB::bind_method(D_METHOD("open_video", "a_path", "a_load_audio"),
							 &Video::open_video, DEFVAL(""), DEFVAL(true));
		ClassDB::bind_method(D_METHOD("close_video"), &Video::close_video);

		ClassDB::bind_method(D_METHOD("is_video_open"), &Video::is_video_open);

		ClassDB::bind_method(D_METHOD("seek_frame", "a_frame_nr"),
							 &Video::seek_frame);
		ClassDB::bind_method(D_METHOD("next_frame"), &Video::next_frame);
		ClassDB::bind_method(D_METHOD("get_audio"), &Video::get_audio);

		ClassDB::bind_method(D_METHOD("get_framerate"), &Video::get_framerate);

		ClassDB::bind_method(D_METHOD("is_framerate_variable"), &Video::is_framerate_variable);
		ClassDB::bind_method(D_METHOD("get_total_frame_nr"), &Video::get_total_frame_nr);
	}
};
