#include "renderer.hpp"
#include <cerrno>
#include <cstddef>
#include <cstdint>
#include <cstdio>
#include <libavcodec/avcodec.h>
#include <libavcodec/codec.h>
#include <libavcodec/codec_id.h>
#include <libavcodec/packet.h>
#include <libavformat/avformat.h>
#include <libavutil/dict.h>
#include <libavutil/frame.h>
#include <libavutil/rational.h>
#include <libswscale/swscale.h>

Renderer::~Renderer() {
	if (av_codec_ctx)
		close();
}

Dictionary Renderer::get_video_file_meta(String a_file_path) {
	AVFormatContext *l_av_format_ctx = NULL;
	const AVDictionaryEntry *l_av_dic = NULL;
	Dictionary l_dic = {};

	if (avformat_open_input(&l_av_format_ctx, a_file_path.utf8(), NULL, NULL)) {
		UtilityFunctions::printerr("Couldn't open file!");
		return l_dic;
	}

	if (avformat_find_stream_info(l_av_format_ctx, NULL)) {
		UtilityFunctions::printerr("Couldn't find stream info!");
		avformat_close_input(&l_av_format_ctx);
		return l_dic;
	}

	while ((l_av_dic = av_dict_iterate(l_av_format_ctx->metadata, l_av_dic)))
		l_dic[l_av_dic->key] = l_av_dic->value;

	avformat_close_input(&l_av_format_ctx);
	return l_dic;
}

Dictionary Renderer::get_supported_codecs() {
	std::pair<AUDIO_CODEC, String> audio_codecs[] = {
		{MP3, "MP3"},
		{AAC, "AAC"},
		{OPUS, "OPUS"},
		{VORBIS, "VORBIS"},
		{FLAC, "FLAC"},
		{AC3, "AC3"},
		{EAC3, "EAC3"},
		{WAV, "WAV"},
	};
	std::pair<VIDEO_CODEC, String> video_codecs[] = {
		{H264, "H264"},
		{H265, "H265"},
		{VP9, "VP9"},
		{MPEG4, "MPEG4"},
		{MPEG2, "MPEG2"},
		{MPEG1, "MPEG1"},
		{AV1, "AV1"},
		{VP8, "VP8"},
	};
	Dictionary l_dic = {}, l_audio_dic = {}, l_video_dic = {};

	for (const auto &l_audio_codec : audio_codecs) {
		const AVCodec *l_codec = avcodec_find_encoder(static_cast<AVCodecID>(l_audio_codec.first));
		Dictionary l_entry = {};
		l_entry["supported"] = is_audio_codec_supported(l_audio_codec.first);
		l_entry["codec_id"] = l_audio_codec.second;
		l_entry["hardware_accel"] = l_codec->capabilities & AV_CODEC_CAP_HARDWARE;
		l_audio_dic[l_audio_codec.second] = l_entry;
	}
	for (const auto &l_video_codec : video_codecs) {
		const AVCodec *l_codec = avcodec_find_encoder(static_cast<AVCodecID>(l_video_codec.first));
		Dictionary l_entry = {};
		l_entry["supported"] = is_video_codec_supported(l_video_codec.first);
		l_entry["codec_id"] = l_video_codec.second;
		l_entry["hardware_accel"] = l_codec->capabilities & AV_CODEC_CAP_HARDWARE;
		l_video_dic[l_video_codec.second] = l_entry;
	}

	l_dic["audio"] = l_audio_dic;
	l_dic["video"] = l_video_dic;
	return l_dic;
}

bool Renderer::is_video_codec_supported(VIDEO_CODEC a_codec) {
	return (const AVCodec *)avcodec_find_encoder(static_cast<AVCodecID>(a_codec));
}

bool Renderer::is_audio_codec_supported(AUDIO_CODEC a_codec) {
	return (const AVCodec *)avcodec_find_encoder(static_cast<AVCodecID>(a_codec));
}

void Renderer::set_output_file_path(String a_file_path) {
	file_path = a_file_path;
}

void Renderer::set_video_codec(VIDEO_CODEC a_video_codec) {
	av_codec_id_video = static_cast<AVCodecID>(a_video_codec);
}

void Renderer::set_audio_codec(AUDIO_CODEC a_audio_codec) {
	av_codec_id_audio = static_cast<AVCodecID>(a_audio_codec);
}

void Renderer::set_resolution(Vector2i a_resolution) {
	resolution = a_resolution;
}

void Renderer::set_frame_rate(int a_frame_rate) {
	frame_rate = a_frame_rate;
}

void Renderer::set_bit_rate(int a_bit_rate) {
	bit_rate = a_bit_rate;
}

bool Renderer::ready_check() {
	return !(file_path.is_empty() ||
			 !av_codec_id_video ||
			 !av_codec_id_audio ||
			 resolution == Vector2i(0, 0) ||
			 frame_rate == -1 ||
			 bit_rate == -1);
}

int Renderer::open() {
	if (!ready_check()) {
		UtilityFunctions::printerr("Render settings not fully setup!");
		return -1;
	}

	av_codec_video = avcodec_find_encoder(av_codec_id_video);
	if (!av_codec_video) {
		UtilityFunctions::printerr("Video codec not found!");
		return -2;
	}
	av_codec_ctx = avcodec_alloc_context3(av_codec_video);
	if (!av_codec_ctx) {
		UtilityFunctions::printerr("Couldn't allocate video codec context!");
		return -2;
	}

	av_codec_ctx->bit_rate = bit_rate;
	av_codec_ctx->pix_fmt = AV_PIX_FMT_YUV420P;
	av_codec_ctx->width = resolution.x;
	av_codec_ctx->height = resolution.y;
	av_codec_ctx->time_base = (AVRational){1, frame_rate};
	av_codec_ctx->framerate = (AVRational){frame_rate, 1};
	av_codec_ctx->gop_size = 10;
	av_codec_ctx->max_b_frames = 1;

	// TODO: Add options in render profile for these type of things
	// if (codec->id == AV_CODEC_ID_H264)
	//   av_opt_set(p_codec_context->priv_data, "preset", "slow", 0);

	if (avcodec_open2(av_codec_ctx, av_codec_video, NULL) < 0) {
		UtilityFunctions::printerr("Couldn't open video codec!");
		return -3;
	}

	output_file = fopen(file_path.utf8(), "wb");
	if (!output_file) {
		UtilityFunctions::printerr("Couldn't open output file!");
		return -4;
	}

	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();
	if (!av_packet || !av_frame) {
		UtilityFunctions::printerr("Couldn't allocate packet/frame!");
		return -5;
	}

	av_frame->format = av_codec_ctx->pix_fmt;
	av_frame->width = av_codec_ctx->width;
	av_frame->height = av_codec_ctx->height;

	if (av_frame_get_buffer(av_frame, 0) < 0) {
		UtilityFunctions::printerr("Couldn't allocate video frame");
		return -6;
	}

	sws_ctx = sws_getContext(
		av_frame->width, av_frame->height, AV_PIX_FMT_RGB24, // AV_PIX_FMT_RGBA
		av_frame->width, av_frame->height, AV_PIX_FMT_YUV420P,
		SWS_BILINEAR, NULL, NULL, NULL); // TODO: Option to change SWS_BILINEAR
	if (!sws_ctx) {
		UtilityFunctions::printerr("Couldn't get sws context!");
		return -7;
	}

	i = 0; // Reset i for send_frame
	return 0;
}

// TODO: Make argument int frame_nr, this could allow for multi-threaded rendering ... maybe
int Renderer::send_frame(Ref<Image> a_frame_image) {
	if (!av_codec_ctx) {
		UtilityFunctions::printerr("No FFmpeg instance running!");
		return -1;
	}

	if (av_frame_make_writable(av_frame) < 0) {
		UtilityFunctions::printerr("Frame is not writeable!");
		return -2;
	}

	uint8_t *l_src_data[4] = {a_frame_image->get_data().ptrw(), NULL, NULL, NULL};
	int l_src_linesize[4] = {av_frame->width * byte_per_pixel, 0, 0, 0};
	sws_scale(sws_ctx, l_src_data, l_src_linesize, 0, av_frame->height, av_frame->data, av_frame->linesize);

	av_frame->pts = i;
	i++;

	response = avcodec_send_frame(av_codec_ctx, av_frame);
	if (response < 0) {
		UtilityFunctions::printerr("Error sending frame for encoding!");
		return -3;
	}

	while (response >= 0) {
		response = avcodec_receive_packet(av_codec_ctx, av_packet);
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
			return -4;
		else if (response < 0) {
			UtilityFunctions::printerr(stderr, "Error during encoding!");
			return -5;
		}

		fwrite(av_packet->data, 1, av_packet->size, output_file);
		av_packet_unref(av_packet);
	}
	return 0;
}

int Renderer::close() {
	if (!av_codec_ctx)
		return 1;

	const uint8_t l_endcode[] = {0, 0, 1, 0xb7};

	// Flush encoder
	response = avcodec_send_frame(av_codec_ctx, NULL);
	if (response < 0) {
		UtilityFunctions::printerr("Error sending frame for encoding!");
		return -1;
	}

	int l_return = 0;
	while (response >= 0) {
		response = avcodec_receive_packet(av_codec_ctx, av_packet);
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF) {
			l_return = -2;
			break;
		} else if (response < 0) {
			UtilityFunctions::printerr(stderr, "Error during encoding!");
			l_return = -3;
			break;
		}
		fwrite(av_packet->data, 1, av_packet->size, output_file);
		av_packet_unref(av_packet);
	}

	// Add sequence endcode to complete file data
	// Does not work for all codecs (some require packets)
	if (av_codec_video->id == AV_CODEC_ID_MPEG1VIDEO || av_codec_video->id == AV_CODEC_ID_MPEG2VIDEO)
		fwrite(l_endcode, 1, sizeof(l_endcode), output_file);
	fclose(output_file);

	avcodec_free_context(&av_codec_ctx);
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);
	sws_freeContext(sws_ctx);

	return l_return;
}
