#pragma once

#include <godot_cpp/classes/image.hpp>
#include <godot_cpp/classes/resource.hpp>
#include <godot_cpp/variant/utility_functions.hpp>

extern "C" {
#include <libavcodec/avcodec.h>
#include <libavcodec/codec.h>
#include <libavcodec/codec_id.h>
#include <libavcodec/packet.h>
#include <libavdevice/avdevice.h>
#include <libavformat/avformat.h>
#include <libavutil/avassert.h>
#include <libavutil/avutil.h>
#include <libavutil/channel_layout.h>
#include <libavutil/dict.h>
#include <libavutil/error.h>
#include <libavutil/frame.h>
#include <libavutil/imgutils.h>
#include <libavutil/mathematics.h>
#include <libavutil/opt.h>
#include <libavutil/pixdesc.h>
#include <libavutil/rational.h>
#include <libavutil/timestamp.h>
#include <libswresample/swresample.h>
#include <libswscale/swscale.h>
}

using namespace godot;

class Renderer : public Resource {
	GDCLASS(Renderer, Resource);

private:
	static const int byte_per_pixel = 4;
	AVFormatContext *av_format_ctx = nullptr;
	const AVOutputFormat *av_out_format = nullptr;
	struct SwsContext *sws_ctx = nullptr;
	struct SwrContext *swr_ctx = nullptr;
	AVCodecContext *av_codec_ctx_video = nullptr, *av_codec_ctx_audio = nullptr;
	const AVCodec *av_codec_video = nullptr, *av_codec_audio = nullptr;
	FILE *output_file = nullptr;
	AVStream *av_stream_video, *av_stream_audio;
	AVPacket *av_packet_video = nullptr, *av_packet_audio = nullptr;
	AVFrame *av_frame_video = nullptr, *av_frame_audio = nullptr;
	int i = 0, x = 0, y = 0, response = 0;

	/* Render requirements */
	String file_path = "";
	AVCodecID av_codec_id_video, av_codec_id_audio;
	Vector2i resolution = Vector2i(1920, 1080);
	int framerate = 30, bit_rate = 400000;
	bool render_audio = false;

	void _encode(AVCodecContext *a_codec_ctx, AVFrame *a_frame, AVPacket *a_packet, FILE *a_output_file);

public:
	enum AUDIO_CODEC {
		MP3 = AV_CODEC_ID_MP3,
		AAC = AV_CODEC_ID_AAC,
		OPUS = AV_CODEC_ID_OPUS,
		VORBIS = AV_CODEC_ID_VORBIS,
		FLAC = AV_CODEC_ID_FLAC,
		PCM_UNCOMPRESSED = AV_CODEC_ID_PCM_S16LE,
		AC3 = AV_CODEC_ID_AC3,
		EAC3 = AV_CODEC_ID_EAC3,
		WAV = AV_CODEC_ID_WAVPACK,
	};
	enum VIDEO_CODEC {
		H264 = AV_CODEC_ID_H264,
		H265 = AV_CODEC_ID_HEVC,
		VP9 = AV_CODEC_ID_VP9,
		MPEG4 = AV_CODEC_ID_MPEG4,
		MPEG2 = AV_CODEC_ID_MPEG2VIDEO,
		MPEG1 = AV_CODEC_ID_MPEG1VIDEO,
		AV1 = AV_CODEC_ID_AV1,
		VP8 = AV_CODEC_ID_VP8,
	};

	~Renderer();

	static Dictionary get_video_file_meta(String a_file_path);

	static Dictionary get_supported_codecs();
	static bool is_video_codec_supported(VIDEO_CODEC a_codec);
	static bool is_audio_codec_supported(AUDIO_CODEC a_codec);

	inline void set_output_file_path(String a_file_path) { file_path = a_file_path; }
	inline String get_output_file_path(String a_file_path) { return file_path; }

	inline void set_video_codec(VIDEO_CODEC a_video_codec) { av_codec_id_video = static_cast<AVCodecID>(a_video_codec);	}
	inline VIDEO_CODEC get_video_codec() { return static_cast<VIDEO_CODEC>(av_codec_id_video); }

	inline void set_audio_codec(AUDIO_CODEC a_audio_codec) { av_codec_id_audio = static_cast<AVCodecID>(a_audio_codec);	}
	inline AUDIO_CODEC get_audio_codec() { return static_cast<AUDIO_CODEC>(av_codec_id_audio); }

	inline void set_resolution(Vector2i a_resolution) { resolution = a_resolution; }
	inline Vector2i get_resolution() { return resolution; }

	inline void set_framerate(int a_framerate) { framerate = a_framerate; }
	inline int get_framerate() { return framerate; }

	inline void set_bit_rate(int a_bit_rate) { bit_rate = a_bit_rate; }
	inline int get_bit_rate() { return bit_rate; }

	inline void set_render_audio(bool a_value) { render_audio = a_value; }
	inline bool get_render_audio() { return render_audio; }

	bool ready_check();

	int open();
	int send_frame(Ref<Image> a_frame_image);
	int close();

protected:
	static inline void _bind_methods() {
		/* AUDIO CODEC ENUMS */
		BIND_ENUM_CONSTANT(MP3);
		BIND_ENUM_CONSTANT(AAC);
		BIND_ENUM_CONSTANT(OPUS);
		BIND_ENUM_CONSTANT(VORBIS);
		BIND_ENUM_CONSTANT(FLAC);
		BIND_ENUM_CONSTANT(PCM_UNCOMPRESSED);
		BIND_ENUM_CONSTANT(AC3);
		BIND_ENUM_CONSTANT(EAC3);
		BIND_ENUM_CONSTANT(WAV);

		/* VIDEO CODEC ENUMS */
		BIND_ENUM_CONSTANT(H264);
		BIND_ENUM_CONSTANT(H265);
		BIND_ENUM_CONSTANT(VP9);
		BIND_ENUM_CONSTANT(MPEG4);
		BIND_ENUM_CONSTANT(MPEG2);
		BIND_ENUM_CONSTANT(MPEG1);
		BIND_ENUM_CONSTANT(AV1);
		BIND_ENUM_CONSTANT(VP8);

		ClassDB::bind_static_method("Renderer", D_METHOD("get_supported_codecs"), &Renderer::get_supported_codecs);
		ClassDB::bind_static_method("Renderer", D_METHOD("get_video_file_meta", "a_file_path"), &Renderer::get_video_file_meta);
		ClassDB::bind_static_method("Renderer", D_METHOD("is_video_codec_supported", "a_video_codec"), &Renderer::is_video_codec_supported);
		ClassDB::bind_static_method("Renderer", D_METHOD("is_audio_codec_supported", "a_audio_codec"), &Renderer::is_audio_codec_supported);

		ClassDB::bind_method(D_METHOD("set_output_file_path", "a_file_path"), &Renderer::set_output_file_path);
		ClassDB::bind_method(D_METHOD("get_output_file_path"), &Renderer::get_output_file_path);

		ClassDB::bind_method(D_METHOD("set_video_codec", "a_video_codec"), &Renderer::set_video_codec);
		ClassDB::bind_method(D_METHOD("get_video_codec"), &Renderer::get_video_codec);

		ClassDB::bind_method(D_METHOD("set_audio_codec", "a_audio_codec"), &Renderer::set_audio_codec);
		ClassDB::bind_method(D_METHOD("get_audio_codec"), &Renderer::get_audio_codec);

		ClassDB::bind_method(D_METHOD("set_resolution", "a_resolution"), &Renderer::set_resolution);
		ClassDB::bind_method(D_METHOD("get_resolution"), &Renderer::get_resolution);

		ClassDB::bind_method(D_METHOD("set_framerate", "a_framerate"), &Renderer::set_framerate);
		ClassDB::bind_method(D_METHOD("get_framerate"), &Renderer::get_framerate);

		ClassDB::bind_method(D_METHOD("set_bit_rate", "a_bit_rate"), &Renderer::set_bit_rate);
		ClassDB::bind_method(D_METHOD("get_bit_rate"), &Renderer::get_bit_rate);

		ClassDB::bind_method(D_METHOD("set_render_audio", "a_value"), &Renderer::set_render_audio);
		ClassDB::bind_method(D_METHOD("get_render_audio"), &Renderer::get_render_audio);

		ClassDB::bind_method(D_METHOD("ready_check"), &Renderer::ready_check);

		ClassDB::bind_method(D_METHOD("open"), &Renderer::open);
		ClassDB::bind_method(D_METHOD("send_frame"), &Renderer::send_frame);
		ClassDB::bind_method(D_METHOD("close"), &Renderer::close);
	}
};

VARIANT_ENUM_CAST(Renderer::VIDEO_CODEC);
