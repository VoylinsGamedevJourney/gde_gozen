#include "renderer.hpp"
#include <cstdint>
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>
#include <libavformat/avio.h>
#include <libavutil/error.h>
#include <libavutil/frame.h>
#include <libavutil/opt.h>
#include <libavutil/samplefmt.h>
#include <libswresample/swresample.h>

// TODO: Set proper return errors and document them!
// TODO: Check if everything is properly freed in close!

Renderer::~Renderer() {
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

bool Renderer::ready_check() {
	if (render_audio)
		return !(file_path.is_empty() || !av_codec_id_video || !av_codec_id_audio);
	else
		return !(file_path.is_empty() || !av_codec_id_video);
}

int Renderer::open() {
	if (!ready_check()) {
		UtilityFunctions::printerr("Render settings not fully setup!");
		return -1;
	}

	// Allocate output media context
	avformat_alloc_output_context2(&av_format_ctx, NULL, NULL, file_path.utf8());
	if (!av_format_ctx) {
		UtilityFunctions::print("Couldn't deduce output format from extensions: using MPEG");
		avformat_alloc_output_context2(&av_format_ctx, NULL, "mpeg", file_path.utf8());
	}
	if (!av_format_ctx) {
		UtilityFunctions::printerr("Couldn't allocate av format context!");
		return -2;
	}
	av_out_format = av_format_ctx->oformat;

	// Setting up video stream
	av_codec_video = avcodec_find_encoder(av_codec_id_video);
	if (!av_codec_video) {
		UtilityFunctions::printerr("Video codec not found!");
		return -3;
	}

	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (!av_codec_ctx_video) {
		UtilityFunctions::printerr("Couldn't allocate video codec context!");
		return -3;
	}

	av_stream_video = avformat_new_stream(av_format_ctx, NULL);
	if (!av_stream_video) {
		UtilityFunctions::printerr("Couldn't create stream!");
		return -3;
	}

	av_codec_ctx_video->codec_id = av_codec_id_video;
	av_codec_ctx_video->bit_rate = bit_rate;
	av_codec_ctx_video->pix_fmt = AV_PIX_FMT_YUV420P;
	av_codec_ctx_video->width = resolution.x;
	av_codec_ctx_video->height = resolution.y;
	av_codec_ctx_video->time_base = (AVRational){1, framerate};
	av_codec_ctx_video->framerate = (AVRational){framerate, 1};
	av_codec_ctx_video->gop_size = 10;
	av_codec_ctx_video->max_b_frames = 1;

	// Setting up audio stream
	if (render_audio) {
		av_codec_audio = avcodec_find_encoder(av_codec_id_audio);
		if (!av_codec_audio) {
			UtilityFunctions::printerr("Audio codec not found!");
			return -3;
		}

		av_codec_ctx_audio = avcodec_alloc_context3(av_codec_audio);
		if (!av_codec_ctx_audio) {
			UtilityFunctions::printerr("Couldn't allocate audio codec context!");
			return -3;
		}

		av_packet_audio = av_packet_alloc();
		if (!av_packet_audio) {
			UtilityFunctions::printerr("Couldn't allocate packet!");
			return -3;
		}

		av_stream_audio = avformat_new_stream(av_format_ctx, NULL);
		if (!av_stream_audio) {
			UtilityFunctions::printerr("Couldn't create new stream!");
			return -3;
		}

		av_codec_ctx_audio->sample_fmt = (*av_codec_audio).sample_fmts ? (*av_codec_audio).sample_fmts[0] : AV_SAMPLE_FMT_FLTP;
		av_codec_ctx_audio->bit_rate = 64000;
		av_codec_ctx_audio->sample_rate = 44100;
		if ((*av_codec_audio).supported_samplerates) {
			av_codec_ctx_audio->sample_rate = (*av_codec_audio).supported_samplerates[0];
			for (i = 0; (*av_codec_audio).supported_samplerates[i]; i++) {
				if ((*av_codec_audio).supported_samplerates[i] == 44100)
					av_codec_ctx_audio->sample_rate = 44100;
			}
		}
		av_channel_layout_copy(&av_codec_ctx_audio->ch_layout, &(AVChannelLayout)AV_CHANNEL_LAYOUT_STEREO);
	}

	// Some formats want stream headers separated
	if (av_format_ctx->oformat->flags & AVFMT_GLOBALHEADER) {
		av_codec_ctx_video->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
		if (render_audio)
			av_codec_ctx_audio->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
	}

	// TODO: Add options in render profile for these type of things
	// if (codec->id == AV_CODEC_ID_H264)
	//   av_opt_set(p_codec_context->priv_data, "preset", "slow", 0);

	// Opening the video encoder codec
	response = avcodec_open2(av_codec_ctx_video, av_codec_video, NULL);
	if (response < 0) {
		UtilityFunctions::printerr("Couldn't open video codec!", av_err2str(response));
		return -3;
	}

	av_packet_video = av_packet_alloc();
	if (!av_packet_video) {
		UtilityFunctions::printerr("Couldn't allocate packet!");
		return -3;
	}
	av_frame_video = av_frame_alloc();
	if (!av_frame_video) {
		UtilityFunctions::printerr("Couldn't allocate frame!");
		return -3;
	}
	av_frame_video->format = AV_PIX_FMT_YUV420P;
	av_frame_video->width = resolution.x;
	av_frame_video->height = resolution.y;
	if (av_frame_get_buffer(av_frame_video, 0)) {
		UtilityFunctions::printerr("Couldn't allocate frame data!");
		return -3;
	}

	sws_ctx = sws_getContext(
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_RGBA, // 24, //AV_PIX_FMT_RGBA
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_YUV420P,
		SWS_BILINEAR, NULL, NULL, NULL); // TODO: Option to change SWS_BILINEAR
	if (!sws_ctx) {
		UtilityFunctions::printerr("Couldn't get sws context!");
		return -7;
	}

	// Copy video stream params to muxer
	if (avcodec_parameters_from_context(av_stream_video->codecpar, av_codec_ctx_video) < 0) {
		UtilityFunctions::printerr("Couldn't copy video stream params!");
		return -3;
	}

	if (render_audio) {
		// Opening the audio encoder codec
		response = avcodec_open2(av_codec_ctx_audio, av_codec_audio, NULL);
		if (response < 0) {
			UtilityFunctions::printerr("Couldn't open audio codec!", av_err2str(response));
			return -4;
		}

		// Copy audio stream params to muxer
		if (avcodec_parameters_from_context(av_stream_audio->codecpar, av_codec_ctx_audio)) {
			UtilityFunctions::printerr("Couldn't copy audio stream params!");
			return -4;
		}

		// Creating resampler
		swr_ctx = swr_alloc();
		if (!swr_ctx) {
			UtilityFunctions::printerr("Couldn't allocate swr!");
			return -4;
		}

		// Setting audio options
		av_opt_set_chlayout(swr_ctx, "in_chlayout", &av_codec_ctx_audio->ch_layout, 0);
		av_opt_set_int(swr_ctx, "in_sample_rate", av_codec_ctx_audio->sample_rate, 0);
		av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", AV_SAMPLE_FMT_S16, 0);
		av_opt_set_chlayout(swr_ctx, "out_chlayout", &av_codec_ctx_audio->ch_layout, 0);
		av_opt_set_int(swr_ctx, "out_sample_rate", av_codec_ctx_audio->sample_rate, 0);
		av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", av_codec_ctx_audio->sample_fmt, 0);

		// Initialize resampling context
		if ((response = swr_init(swr_ctx)) < 0) {
			UtilityFunctions::printerr("Failed to initialize resampling context!");
			return -4;
		}
	}

	av_dump_format(av_format_ctx, 0, file_path.utf8(), 1);

	// Open output file if needed
	if (!(av_out_format->flags & AVFMT_NOFILE)) {
		response = avio_open(av_format_ctx->pb, file_path.utf8(), AVIO_FLAG_WRITE);
		if (response < 0) {
			UtilityFunctions::printerr("Couldn't open output file!", av_err2str(response));
			return -5;
		}
	}

	// Write stream header - if any
	response = avformat_write_header(av_format_ctx, NULL);
	if (response < 0) {
		UtilityFunctions::printerr("Error when writing header!", av_err2str(response));
		return -6;
	}

	i = 0; // Reset i for send_frame
	return 0;
}

// TODO: Make argument int frame_nr, this could allow for multi-threaded rendering ... maybe
int Renderer::send_frame(Ref<Image> a_frame_image) {
	if (!av_codec_ctx_video) {
		UtilityFunctions::printerr("Video codec isn't open!");
		return -1;
	}

	if (av_frame_make_writable(av_frame) < 0) {
		UtilityFunctions::printerr("Frame is not writeable!");
		return -2;
	}
	uint8_t *l_src_data[4] = {a_frame_image->get_data().ptrw(), NULL, NULL, NULL};
	int l_src_linesize[4] = {av_frame->width * byte_per_pixel, 0, 0, 0};
	//	sws_scale(sws_ctx, l_src_data, l_src_linesize, 0, av_frame->height, av_frame->data, av_frame->linesize);
	for (y = 0; y < av_codec_ctx->height; y++) {
		for (x = 0; x < av_codec_ctx->width; x++) {
			av_frame->data[0][y * av_frame->linesize[0] + x] = x + y + i * 3;
		}
	}

	/* Cb and Cr */
	for (y = 0; y < av_codec_ctx->height / 2; y++) {
		for (x = 0; x < av_codec_ctx->width / 2; x++) {
			av_frame->data[1][y * av_frame->linesize[1] + x] = 128 + y + i * 2;
			av_frame->data[2][y * av_frame->linesize[2] + x] = 64 + x + i * 5;
		}
	}

	av_frame->pts = i;
	i++;
	_encode(av_codec_ctx, av_frame, av_packet, output_file);
	return 0;
}

int Renderer::send_audio(Ref<AudioStreamWAV> a_wav) {
	if (render_audio) {
		UtilityFunctions::printerr("Audio not enabled for this renderer!");
		return -1;
	} else if (!av_codec_ctx_audio) {
		UtilityFunctions::printerr("Audio codec isn't open!");
		return -2;
	}

	i = 0;	
	// LOOP over data
	// uint16_t *l_data = (int16_t*)av_frame_audio->data[0];
	// for (int j = 0; j < av_frame_audio->nb_samples; j++) {
	//		l_v = (int)(sin
	// }
	// av_frame_pts = i;
	// i += av_frame_audio->nb_samples;
	// while loop end to repeat

	return 0;
}

int Renderer::close() {
	if (av_codec_ctx == nullptr)
		return 1;

	av_write_trailer(av_format_ctx);

	avcodec_free_context(&av_codec_ctx_video);
	av_frame_free(&av_frame_video);
	av_packet_free(&av_packet_video);
	sws_freeContext(sws_ctx);

	if (render_audio) {
		avcodec_free_context(&av_codec_ctx_audio);
		av_frame_free(&av_frame_audio);
		av_packet_free(&av_packet_audio);
		swr_free(swr_ctx);
	}

	if (!(av_out_format->flags) & AVFMT_NOFILE))
		avio_closep(av_format_ctx->pb);
	avformat_free_context(av_format_ctx);

	return 0;
}
