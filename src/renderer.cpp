#include "renderer.hpp"

// TODO: Only show encoders to people which support S16

Renderer::~Renderer() {
	close();
}

int Renderer::open() {
	if (renderer_open) {
		UtilityFunctions::printerr("Render already open!");
		return -1;
	} else {
		if (path == "") {
			UtilityFunctions::printerr("Path is not set!");
			return -2;
		} else if (video_codec == -1) {
			UtilityFunctions::printerr("Video codec not set!");
			return -3;
		} else if (audio_codec == -1) {
			_print_debug("Audio codec not set, not rendering audio!");
		}else if (audio_codec != -1 && sample_rate -1) {
			UtilityFunctions::printerr("A sample rate needs to be set for audio exporting!");
			audio_codec = -1;
		}
	}

	avformat_alloc_output_context2(&av_format_ctx, NULL, NULL, path.utf8());
	if (!av_format_ctx) {
		UtilityFunctions::printerr("Couldn't allocate av format context!");
		return -4;
	}

	const AVCodec *av_codec_video = avcodec_find_encoder((AVCodecID)video_codec);
	if (!av_codec_video) {
		UtilityFunctions::printerr("Video codec not found!");
		return -5;
	}

	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (!av_codec_ctx_video) {
		UtilityFunctions::printerr("Couldn't allocate video codec context!");
		return -5;
	}

	av_stream_video = avformat_new_stream(av_format_ctx, NULL);
	if (!av_stream_video) {
		UtilityFunctions::printerr("Couldn't create stream!");
		return -6;
	}

	FFmpeg::enable_multithreading(av_codec_ctx_video, av_codec_video);

	av_codec_ctx_video->codec_id = (AVCodecID)video_codec;
	av_codec_ctx_video->bit_rate = bit_rate;
	av_codec_ctx_video->pix_fmt = AV_PIX_FMT_YUV420P;
	av_codec_ctx_video->width = resolution.x;
	av_codec_ctx_video->height = resolution.y;
	av_codec_ctx_video->time_base = (AVRational){1, (int)framerate};
	av_codec_ctx_video->framerate = (AVRational){(int)framerate, 1};
	av_codec_ctx_video->gop_size = gop_size;
	av_codec_ctx_video->max_b_frames = 1;

	// Some formats want stream headers separated
	if (av_format_ctx->oformat->flags & AVFMT_GLOBALHEADER)
		av_codec_ctx_video->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;

	// TODO: Encoding options for different codecs
	// if (av_codec_video->id == AV_CODEC_ID_H264)
	//	av_opt_set(av_codec_ctx_video->priv_data, "preset", h264_preset, 0);

	// Opening the video encoder codec
	response = avcodec_open2(av_codec_ctx_video, av_codec_video, NULL);
	if (response < 0) {
		FFmpeg::print_av_error("Couldn't open video codec context!", response);
		return -7;
	}

	av_packet_video = av_packet_alloc();
	if (!av_packet_video) {
		UtilityFunctions::printerr("Couldn't allocate packet!");
		return -8;
	}
	av_frame_video = av_frame_alloc();
	if (!av_frame_video) {
		UtilityFunctions::printerr("Couldn't allocate frame!");
		return -8;
	}
	av_frame_video->format = AV_PIX_FMT_YUV420P;
	av_frame_video->width = resolution.x;
	av_frame_video->height = resolution.y;
	if (av_frame_get_buffer(av_frame_video, 0)) {
		UtilityFunctions::printerr("Couldn't allocate frame data!");
		return -8;
	}

	// Copy video stream params to muxer
	if (avcodec_parameters_from_context(av_stream_video->codecpar, av_codec_ctx_video) < 0) {
		UtilityFunctions::printerr("Couldn't copy video stream params!");
		return -9;
	}

	av_dump_format(av_format_ctx, 0, path.utf8(), 1);

	// Open output file if needed
	if (!(av_format_ctx->oformat->flags & AVFMT_NOFILE)) {
		response = avio_open(&av_format_ctx->pb, path.utf8(), AVIO_FLAG_WRITE);
		if (response < 0) {
			FFmpeg::print_av_error("Couldn't open output file!", response);
			return -10;
		}
	}

	if (audio_codec != -1) {
		av_stream_audio = avformat_new_stream(av_format_ctx, NULL);
		if (!av_stream_audio) {
			UtilityFunctions::printerr("Couldn't create new stream!");
			return -3;
		}

		const AVCodec *av_codec_audio = avcodec_find_encoder((AVCodecID)audio_codec);
		if (!av_codec_audio) {
			UtilityFunctions::printerr("Audio codec not found!");
			return -4;
		}

		av_codec_ctx_audio = avcodec_alloc_context3(av_codec_audio);
		if (!av_codec_ctx_audio) {
			UtilityFunctions::printerr("Couldn't allocate audio codec context!");
			return -5;
		}

		FFmpeg::enable_multithreading(av_codec_ctx_audio, av_codec_audio);

		av_codec_ctx_audio->sample_fmt = AV_SAMPLE_FMT_S16;
		av_codec_ctx_audio->bit_rate = sample_rate * 16; // Sample rate * bit depth
		av_codec_ctx_audio->sample_rate = sample_rate;
		if ((*av_codec_audio).supported_samplerates) {
			av_codec_ctx_audio->sample_rate = (*av_codec_audio).supported_samplerates[0];
			for (frame_nr = 0; (*av_codec_audio).supported_samplerates[frame_nr]; frame_nr++) {
				if ((*av_codec_audio).supported_samplerates[frame_nr] == 44100)
					av_codec_ctx_audio->sample_rate = 44100;
			}
		}

		AVChannelLayout l_ch_layout = AV_CHANNEL_LAYOUT_STEREO;
		av_channel_layout_copy(&av_codec_ctx_audio->ch_layout, &(l_ch_layout));

		// Opening the audio encoder codec
		response = avcodec_open2(av_codec_ctx_audio, av_codec_audio, NULL);
		if (response < 0) {
			FFmpeg::print_av_error("Couldn't open audio codec!", response);
			return -4;
		}

		av_stream_audio->time_base = (AVRational){1, av_codec_ctx_audio->sample_rate};

		// Copy audio stream params to muxer
		if (avcodec_parameters_from_context(av_stream_audio->codecpar, av_codec_ctx_audio)) {
			UtilityFunctions::printerr("Couldn't copy audio stream params!");
			return -4;
		}

		if (av_format_ctx->oformat->flags & AVFMT_GLOBALHEADER)
			av_codec_ctx_audio->flags |= AV_CODEC_FLAG_GLOBAL_HEADER;
	}

	// Write stream header - if any
	response = avformat_write_header(av_format_ctx, NULL);
	if (response < 0) {
		FFmpeg::print_av_error("Error when writing header!", response);
		return -11;
	}

	// Setting up SWS
	sws_ctx = sws_getContext(
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_RGBA,
		av_frame_video->width, av_frame_video->height, AV_PIX_FMT_YUV420P,
		SWS_BILINEAR, NULL, NULL, NULL);
	if (!sws_ctx) {
		UtilityFunctions::printerr("Couldn't get sws context!");
		return -12;
	}

	av_packet_free(&av_packet_video);

	frame_nr = 0;
	renderer_open = true;
	return OK;
}

int Renderer::send_frame(Ref<Image> a_image) {
	if (!renderer_open) {
		UtilityFunctions::printerr("Renderer isn't open!");
		return -6;
	} else if (audio_codec != -1 && !audio_added) {
		UtilityFunctions::printerr("Audio codec set but not added yet!");
		return -1;
	} else if (!av_codec_ctx_video) {
		UtilityFunctions::printerr("Video codec isn't open!");
		return -2;
	}

	if (av_frame_make_writable(av_frame_video) < 0) {
		UtilityFunctions::printerr("Video frame is not writeable!");
		return -3;
	}

	uint8_t *l_src_data[4] = { a_image->get_data().ptrw(), NULL, NULL, NULL };
	int l_src_linesize[4] = { av_frame_video->width * 4, 0, 0, 0 };
	response = sws_scale(
			sws_ctx,
			l_src_data, l_src_linesize, 0, av_frame_video->height,
			av_frame_video->data, av_frame_video->linesize);
	if (response < 0) {
		FFmpeg::print_av_error("Scaling frame data failed!", response);
		return -4;
	}

	av_frame_video->pts = frame_nr;
	frame_nr++;

	// Adding frame
	response = avcodec_send_frame(av_codec_ctx_video, av_frame_video);
	if (response < 0) {
		FFmpeg::print_av_error("Error sending video frame!", response);
		return -5;
	}

	av_packet_video = av_packet_alloc();

	while (response >= 0) {
		response = avcodec_receive_packet(av_codec_ctx_video, av_packet_video);
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
			break;
		else if (response < 0) {
			FFmpeg::print_av_error("Error encoding video frame!", response);
			response = -1;
			av_packet_free(&av_packet_video);
			return response;
		}

		// Rescale output packet timestamp values from codec to stream timebase
		av_packet_video->stream_index = av_stream_video->index;
		av_packet_rescale_ts(av_packet_video, av_codec_ctx_video->time_base, av_stream_video->time_base);

		// Write the frame to file
		response = av_interleaved_write_frame(av_format_ctx, av_packet_video);
		// Packet is now blank as function above takes ownership of it, so no unreferencing is necessary.
		// When using av_write_frame this would be needed.
		if (response < 0) {
			FFmpeg::print_av_error("Error whilst writing output packet!", response);
			response = -1;
			av_packet_free(&av_packet_video);
			return response;
		}

		av_packet_unref(av_packet_video);
	}

	av_packet_free(&av_packet_video);
	return 0;
}

int Renderer::send_audio(Ref<AudioStreamWAV> a_wav) {
	if (!renderer_open) {
		UtilityFunctions::printerr("Renderer isn't open!");
		return -6;
	} else if (audio_codec == -1) {
		UtilityFunctions::printerr("Audio not enabled for this renderer!");
		return -1;
	} else if (audio_added) {
		UtilityFunctions::printerr("Audio already added!");
		return -2;
	}

	// Creating resampler
//	swr_ctx = swr_alloc();
//	if (!swr_ctx) {
//		UtilityFunctions::printerr("Couldn't allocate swr!");
//		return -10;
//	}
//
//	// Setting audio options
//	av_opt_set_chlayout(swr_ctx, "in_chlayout", &av_codec_ctx_audio->ch_layout, 0);
//	av_opt_set_int(swr_ctx, "in_sample_rate", av_codec_ctx_audio->sample_rate, 0);
//	av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", AV_SAMPLE_FMT_S16, 0);
//	av_opt_set_chlayout(swr_ctx, "out_chlayout", &av_codec_ctx_audio->ch_layout, 0);
//	av_opt_set_int(swr_ctx, "out_sample_rate", av_codec_ctx_audio->sample_rate, 0);
//	av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", av_codec_ctx_audio->sample_fmt, 0);
//
//	// Initialize resampling context
//	if ((response = swr_init(swr_ctx)) < 0) {
//		UtilityFunctions::printerr("Failed to initialize resampling context!");
//		return -10;
//	}
	
	av_packet_audio = av_packet_alloc();
	av_frame_audio = av_frame_alloc();
	if (!av_packet_audio || !av_frame_audio) {
		UtilityFunctions::printerr("Couldn't allocate packet and/or frame for audio!");
		return -7;
	}
	av_frame_audio->nb_samples = av_codec_ctx_audio->frame_size;
	av_frame_audio->format = av_codec_ctx_audio->sample_fmt;
	response = av_channel_layout_copy(&av_frame_audio->ch_layout, &av_codec_ctx_audio->ch_layout);
	if (response < 0) {
		FFmpeg::print_av_error("Couldn't copy channel layout for audio!", response);
		return -8;
	}

	response = av_frame_get_buffer(av_frame_audio, 0);
	if (response < 0) {
		FFmpeg::print_av_error("Couldn't get frame buffer!", response);
		return -9;
	}

	const uint8_t *l_pcm_data = a_wav->get_data().ptr();
	size_t l_pcm_size = a_wav->get_data().size();
	int l_total_samples = l_pcm_size / 2 / (a_wav->is_stereo() ? 2 : 1);
		
	for (int i = 0; i < l_total_samples; i += av_codec_ctx_audio->frame_size) {
		int l_frame_samples = MIN(av_codec_ctx_audio->frame_size, l_total_samples - i);
		
		// Ensure frame is writable
		if (av_frame_make_writable(av_frame_audio) < 0) {
			UtilityFunctions::printerr("Couldn't make frame writable!");
			return -10;
		}

		// Populate frame data
		uint16_t *l_samples = (uint16_t *)av_frame_audio->data[0];
		memcpy(l_samples, l_pcm_data + i * 2 * (a_wav->is_stereo() ? 2 : 1), l_frame_samples * 2 * (a_wav->is_stereo() ? 2 : 1));

		av_frame_audio->nb_samples = l_frame_samples;

		response = avcodec_send_frame(av_codec_ctx_audio, av_frame_audio);
		if (response < 0) {
			FFmpeg::print_av_error("Error sending frame to encoder!", response);
			return -11;
		}

		while (response >= 0) {
			response = avcodec_receive_packet(av_codec_ctx_audio, av_packet_audio);
			if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
				break;
			else if (response < 0) {
				FFmpeg::print_av_error("Error encoding audio frame!", response);
				return -12;
			}

			av_packet_rescale_ts(av_packet_audio, av_codec_ctx_audio->time_base, av_stream_audio->time_base);
			av_packet_audio->stream_index = av_stream_audio->index;

			response = av_interleaved_write_frame(av_format_ctx, av_packet_audio);
			if (response < 0) {
				FFmpeg::print_av_error("Error writing packet!", response);
				return -13;
			}

			av_packet_unref(av_packet_audio);
		}
	}

	// Flushing encoder
	response = avcodec_send_frame(av_codec_ctx_audio, nullptr);
	if (response < 0) {
		FFmpeg::print_av_error("Error sending frame to encoder!", response);
		return -11;
	}

	while (response >= 0) {
		response = avcodec_receive_packet(av_codec_ctx_audio, av_packet_audio);
		if (response == AVERROR(EAGAIN) || response == AVERROR_EOF)
			break;
		else if (response < 0) {
			FFmpeg::print_av_error("Error encoding audio frame!", response);
			return -12;
		}

		av_packet_rescale_ts(av_packet_audio, av_codec_ctx_audio->time_base, av_stream_audio->time_base);
		av_packet_audio->stream_index = av_stream_audio->index;

		response = av_interleaved_write_frame(av_format_ctx, av_packet_audio);
		if (response < 0) {
			FFmpeg::print_av_error("Error writing packet!", response);
			return -13;
		}

		av_packet_unref(av_packet_audio);
	}

	avcodec_free_context(&av_codec_ctx_audio);
	av_frame_free(&av_frame_audio);
	av_packet_free(&av_packet_audio);
//	swr_free(&swr_ctx);

	audio_added = true;
	return OK;
}

int Renderer::close() {
	if (av_codec_ctx_video == nullptr)
		return -1;

	av_write_trailer(av_format_ctx);

	avcodec_free_context(&av_codec_ctx_video);

	av_frame_free(&av_frame_video);
	av_packet_free(&av_packet_video);

	sws_freeContext(sws_ctx);

	if (!(av_format_ctx->oformat->flags & AVFMT_NOFILE))
		avio_closep(&av_format_ctx->pb);

	avformat_free_context(av_format_ctx);

	return OK;
}

void Renderer::_print_debug(std::string a_text) {
	if (debug)
		UtilityFunctions::print(a_text.c_str());
}

void Renderer::_printerr_debug(std::string a_text) {
	if (debug)
		UtilityFunctions::print(a_text.c_str());
}
