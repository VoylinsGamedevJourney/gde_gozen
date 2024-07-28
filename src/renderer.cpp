#include "renderer.hpp"

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

	av_packet_video = av_packet_alloc();
	if (!av_packet_video) {
		UtilityFunctions::printerr("Couldn't allocate packet!");
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

 I am here!!
	// Opening the video encoder codec
	if (avcodec_open2(av_codec_ctx_video, av_codec_video, NULL) < 0) {
		UtilityFunctions::printerr("Couldn't open video codec!");
		return -3;
	}

	output_file = fopen(file_path.utf8(), "wb");
	if (!output_file) {
		UtilityFunctions::printerr("Couldn't open output file!");
		return -4;
	}

	av_frame = av_frame_alloc();
	if (!av_frame) {
		UtilityFunctions::printerr("Couldn't allocate frame!");
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
		av_frame->width, av_frame->height, AV_PIX_FMT_RGBA, // 24, //AV_PIX_FMT_RGBA
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

int Renderer::close() {
	if (av_codec_ctx == nullptr)
		return 1;

	// Flush encoder
	_encode(av_codec_ctx, NULL, av_packet, output_file);

	// Add sequence endcode to complete file data
	// Does not work for all codecs (some require packets)
	const uint8_t l_endcode[] = {0, 0, 1, 0xb7};
	if (av_codec_video->id == AV_CODEC_ID_MPEG1VIDEO ||
		av_codec_video->id == AV_CODEC_ID_MPEG2VIDEO)
		fwrite(l_endcode, 1, sizeof(l_endcode), output_file);
	fclose(output_file);

	avcodec_free_context(&av_codec_ctx);
	av_frame_free(&av_frame);
	av_packet_free(&av_packet);
	sws_freeContext(sws_ctx);

	return 0;
}

void Renderer::_encode(AVCodecContext *a_codec_ctx, AVFrame *a_frame, AVPacket *a_packet, FILE *a_output_file) {
	response = avcodec_send_frame(a_codec_ctx, a_frame);
	if (response < 0) {
		UtilityFunctions::printerr("Error sending frame for encoding!");
		return;
	}

	while (response >= 0) {
		response = avcodec_receive_packet(a_codec_ctx, a_packet);
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
			return;
		else if (response < 0) {
			UtilityFunctions::printerr(stderr, "Error during encoding!");
			return;
		}
		fwrite(a_packet->data, 1, a_packet->size, a_output_file);
		av_packet_unref(a_packet);
	}
}
