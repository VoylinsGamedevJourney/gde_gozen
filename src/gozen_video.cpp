#include "gozen_video.hpp"


//----------------------------------------------- STATIC FUNCTIONS
Dictionary GoZenVideo::get_file_meta(String a_file_path) {
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

//----------------------------------------------- NON-STATIC FUNCTIONS
int GoZenVideo::open(const String& a_path) {
	if (loaded)
			return _log_err("Already open");

	path = a_path;

	// Allocate video file context
	AVFormatContext* temp_format_ctx = nullptr;
	if (avformat_open_input(&temp_format_ctx, path.utf8(), NULL, NULL)) {
		close();
		return _log_err("Couldn't open video");
	}
	av_format_ctx = make_unique_ffmpeg<AVFormatContext, AVFormatCtxInputDeleter>(
			temp_format_ctx);

	// Getting video stream information
	avformat_find_stream_info(av_format_ctx.get(), NULL);

	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO  &&
				!(av_format_ctx->streams[i]->disposition & AV_DISPOSITION_ATTACHED_PIC)) {
			av_stream = av_format_ctx->streams[i];
			resolution.x = av_codec_params->width;
			resolution.y = av_codec_params->height;
			color_profile = av_codec_params->color_primaries;

			AVDictionaryEntry *l_rotate_tag = av_dict_get(av_stream->metadata, "rotate", nullptr, 0);
			rotation = l_rotate_tag ? atoi(l_rotate_tag->value) : 0;
			if (rotation == 0) { // Check modern rotation detecting
				for (int i = 0; i < av_stream->codecpar->nb_coded_side_data; ++i) {
					const AVPacketSideData *side_data = &av_stream->codecpar->coded_side_data[i];

					if (side_data->type == AV_PKT_DATA_DISPLAYMATRIX && side_data->size == sizeof(int32_t) * 9)
						rotation = av_display_rotation_get(reinterpret_cast<const int32_t *>(side_data->data));
				}
			}

			continue;
		}
		av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
	}

	// Setup Decoder codec context
	const AVCodec *av_codec = avcodec_find_decoder(av_stream->codecpar->codec_id);
	if (!av_codec) {
		close();
		return _log_err("Couldn't find decoder");
	}

	// Allocate codec context for decoder
	av_codec_ctx = make_unique_ffmpeg<AVCodecContext, AVCodecCtxDeleter>(
			avcodec_alloc_context3(av_codec));
	if (av_codec_ctx == NULL) {
		close();
		return _log_err("Failed alloc codec");
	}
	
	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx.get(), av_stream->codecpar)) {
		close();
		return _log_err("Couldn't init codec");
	}

	FFmpeg::enable_multithreading(av_codec_ctx.get(), av_codec);
	
	// Open codec - Video
	if (avcodec_open2(av_codec_ctx.get(), av_codec, NULL)) {
		close();
		return _log_err("Couldn't open codec");
	}

	float l_aspect_ratio = av_q2d(av_stream->codecpar->sample_aspect_ratio);
	if (l_aspect_ratio > 1.0)
		resolution.x = static_cast<int>(std::round(resolution.x * l_aspect_ratio));

	pixel_format = av_get_pix_fmt_name(av_codec_ctx->pix_fmt);
	_log(String("Selected pixel format is: ") + pixel_format);

	start_time_video = av_stream->start_time != AV_NOPTS_VALUE ? (int64_t)(av_stream->start_time * stream_time_base_video) : 0;

	// Getting some data out of first frame
	av_packet = make_unique_avpacket();
	av_frame = make_unique_avframe();
	av_sws_frame = make_unique_avframe();
	if (!av_packet || !av_frame || !av_sws_frame) {
		close();
		return _log_err("Couldn't alloc packed/frames");
	}

	avcodec_flush_buffers(av_codec_ctx.get());
	bool l_duration_from_bitrate = av_format_ctx->duration_estimation_method == AVFMT_DURATION_FROM_BITRATE;
	if (l_duration_from_bitrate) {
		close();
		return _log_err("Invalid video");
	}

	int attempts = 0;
	while (true) {
		response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
									 av_stream->index, av_frame.get(), av_packet.get());

		if (response == 0)
			break;
		else if (response == AVERROR(EAGAIN) || response == AVERROR(EWOULDBLOCK)) {
			if (attempts > 10) {
				FFmpeg::print_av_error("Reached max attempts trying to get first frame!", response);
				break;
			}

			attempts++;
		} else if (response == AVERROR_EOF) {
			FFmpeg::print_av_error("Reached EOF trying to get first frame!", response);
			break;
		} else {
			FFmpeg::print_av_error("Something went wrong getting first frame!", response);
			break;
		}
	}
	
	// Checking for interlacing and what type of interlacing
	if (av_frame->flags & AV_FRAME_FLAG_INTERLACED)
		interlaced = av_frame->flags & AV_FRAME_FLAG_TOP_FIELD_FIRST ? 1 : 2;

	// Checking color range
	full_color_range = av_frame->color_range == AVCOL_RANGE_JPEG;

	// Getting frame rate
	// - Average framerate
	if (av_stream->avg_frame_rate.num > 0 && av_stream->avg_frame_rate.den > 0) {
		double avg_rate = av_q2d(av_stream->avg_frame_rate);
		if (avg_rate > 0.1) framerate = avg_rate;
	}

	// - Real framerate (not always correct)
	if (framerate <= 0.1 && av_stream->r_frame_rate.num > 0 && av_stream->r_frame_rate.den > 0) {
		double r_rate = av_q2d(av_stream->r_frame_rate);
		if (r_rate > 0.1) framerate = r_rate;
	}

	// - Guess the framerate
	if (framerate <= 0.1) {
		AVRational guessed_rate_q = av_guess_frame_rate(av_format_ctx.get(), av_stream, av_frame.get());
		double guessed_rate = av_q2d(guessed_rate_q);

		if (guessed_rate > 0.1) framerate = guessed_rate;
	}

	if (framerate <= 0) { // Make sure we have a valid framerate after all checks
		close();
		return _log_err("Invalid framerate (could not be determined)");
	}

	// Setting variables
	average_frame_duration = 10000000.0 / framerate; // eg. 1 sec / 25 fps = 400.000 ticks (40ms)
	stream_time_base_video = av_q2d(av_stream->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks

	// Preparing the data array's
	if (av_frame->format == AV_PIX_FMT_YUV420P) {
		y_data = Image::create_empty(av_frame->linesize[0], resolution.y, false, Image::FORMAT_R8);
		u_data = Image::create_empty(av_frame->linesize[1], resolution.y/2, false, Image::FORMAT_R8);
		v_data = Image::create_empty(av_frame->linesize[2], resolution.y/2, false, Image::FORMAT_R8);
		padding = av_frame->linesize[0] - resolution.x;
	} else {
		using_sws = true;
		sws_ctx = make_unique_ffmpeg<SwsContext, SwsCtxDeleter>(sws_getContext(
						resolution.x, resolution.y, av_codec_ctx->pix_fmt,
						resolution.x, resolution.y, AV_PIX_FMT_YUV420P,
						SWS_BICUBIC, NULL, NULL, NULL));

		// We will use av_hw_frame to convert the frame data to as we won't use it anyway without hw decoding.
		av_sws_frame = make_unique_avframe();
		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		y_data = Image::create_empty(av_sws_frame->linesize[0], resolution.y, false, Image::FORMAT_R8);
		u_data = Image::create_empty(av_sws_frame->linesize[1], resolution.y/2, false, Image::FORMAT_R8);
		v_data = Image::create_empty(av_sws_frame->linesize[2], resolution.y/2, false, Image::FORMAT_R8);
		padding = av_sws_frame->linesize[0] - resolution.x;

		av_frame_unref(av_sws_frame.get());
	}

	// Set the aspect ratio.
	sar = av_q2d(av_stream->codecpar->sample_aspect_ratio);

	// Checking second frame
	if ((response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(), av_stream->index, av_frame.get(), av_packet.get())))
		FFmpeg::print_av_error("Something went wrong getting second frame!", response);

	duration = av_format_ctx->duration;
	if (av_stream->duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
		if (duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
			close();
			return _log_err("Invalid video duration");
		} else {
			AVRational l_temp_rational = AVRational{1, AV_TIME_BASE};
			if (l_temp_rational.num != av_stream->time_base.num || l_temp_rational.num != av_stream->time_base.num)
				duration = std::ceil(static_cast<double>(duration) * av_q2d(l_temp_rational) / av_q2d(av_stream->time_base));
		}
		av_stream->duration = duration;
	}

	if (av_stream->nb_frames > 0) {
		frame_count = av_stream->nb_frames;
	} else {
		frame_count = static_cast<int>(std::round((static_cast<double>(duration) / static_cast<double>(AV_TIME_BASE)) * framerate));
	}

	if (av_packet)
		av_packet_unref(av_packet.get());
	if (av_frame)
		av_frame_unref(av_frame.get());

	loaded = true;
	response = OK;

	return OK;
}

void GoZenVideo::close() {
	_log("Closing video file on path: " + path);
	loaded = false;

	av_packet.reset();
	av_frame.reset();
	av_sws_frame.reset();

	sws_ctx.reset();

	av_codec_ctx.reset();
	av_format_ctx.reset();
}

int GoZenVideo::seek_frame(int a_frame_nr) {
	if (!loaded)
		return _log_err("Video is not open");

	// Video seeking
	if ((response = _seek_frame(a_frame_nr)) < 0)
		return _log_err("Couldn't seek video");
	
	while (true) {
		if ((response = FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(),
									av_stream->index, av_frame.get(), av_packet.get()))) {
			if (response == AVERROR_EOF) {
				_log("End of file reached! Going back 1 frame!");

				if ((response = _seek_frame(a_frame_nr--)) < 0)
					return _log_err("Couldn't seek video");

				continue;
			}
			FFmpeg::print_av_error("Problem happened getting frame in seek_frame! ", response);
			response = 1;
			break;
		}

		// Get frame pts
		current_pts = av_frame->best_effort_timestamp == AV_NOPTS_VALUE ? av_frame->pts : av_frame->best_effort_timestamp;
		if (current_pts == AV_NOPTS_VALUE)
			continue;

		// Skip to actual requested frame
		if ((int64_t)(current_pts * stream_time_base_video) / 10000 >=
			frame_timestamp / 10000) {
			_copy_frame_data();
			break;
		}
	}

	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());

	return OK;
}

bool GoZenVideo::next_frame(bool a_skip) {
	if (!loaded)
		return false;

	FFmpeg::get_frame(av_format_ctx.get(), av_codec_ctx.get(), av_stream->index, av_frame.get(), av_packet.get());

	if (!a_skip)
		_copy_frame_data();

	av_frame_unref(av_frame.get());
	av_packet_unref(av_packet.get());
	
	return true;
}

void GoZenVideo::_copy_frame_data() {
	if (av_frame->data[0] == nullptr) {
		_log_err("Frame is empty!");
		return;
	}

	if (using_sws) {
		sws_scale_frame(sws_ctx.get(), av_sws_frame.get(), av_frame.get());

		memcpy(y_data->ptrw(), av_sws_frame->data[0], y_data->get_size().x * y_data->get_size().y);
		memcpy(u_data->ptrw(), av_sws_frame->data[1], u_data->get_size().x * u_data->get_size().y);
		memcpy(v_data->ptrw(), av_sws_frame->data[2], v_data->get_size().x * v_data->get_size().y);

		av_frame_unref(av_sws_frame.get());
	} else {
		memcpy(y_data->ptrw(), av_frame->data[0], y_data->get_size().x * y_data->get_size().y);
		memcpy(u_data->ptrw(), av_frame->data[1], u_data->get_size().x * u_data->get_size().y);
		memcpy(v_data->ptrw(), av_frame->data[2], v_data->get_size().x * v_data->get_size().y);
	}
}

int GoZenVideo::_seek_frame(int a_frame_nr) {
	avcodec_flush_buffers(av_codec_ctx.get());

	frame_timestamp = (int64_t)(a_frame_nr * average_frame_duration);
	return av_seek_frame(av_format_ctx.get(), -1, (start_time_video + frame_timestamp) / 10, AVSEEK_FLAG_BACKWARD | AVSEEK_FLAG_FRAME);
}

#define BIND_STATIC_METHOD(method_name) \
	ClassDB::bind_static_method("GoZenVideo", D_METHOD(#method_name), &GoZenVideo::method_name)

#define BIND_STATIC_METHOD_1(method_name, param1) \
	ClassDB::bind_static_method("GoZenVideo",  \
		D_METHOD(#method_name, param1), &GoZenVideo::method_name)

#define BIND_METHOD(method_name) \
	ClassDB::bind_method(D_METHOD(#method_name), &GoZenVideo::method_name)

#define BIND_METHOD_1(method_name, param1) \
	ClassDB::bind_method( \
		D_METHOD(#method_name, param1), &GoZenVideo::method_name)

void GoZenVideo::_bind_methods() {
	BIND_STATIC_METHOD_1(get_file_meta, "a_file_path");

	BIND_METHOD_1(open, "a_path");

	BIND_METHOD(is_open);

	BIND_METHOD_1(seek_frame, "a_frame_nr");
	BIND_METHOD_1(next_frame, "a_skip");
	BIND_METHOD(get_audio);

	BIND_METHOD(get_framerate);

	BIND_METHOD(get_path);

	BIND_METHOD(get_resolution);
	BIND_METHOD(get_width);
	BIND_METHOD(get_height);
	BIND_METHOD(get_padding);
	BIND_METHOD(get_rotation);

	BIND_METHOD(get_frame_count);
	BIND_METHOD(get_sar);

	BIND_METHOD(enable_debug);
	BIND_METHOD(disable_debug);
	BIND_METHOD(get_debug_enabled);

	BIND_METHOD(get_pixel_format);
	BIND_METHOD(get_color_profile);

	BIND_METHOD(is_full_color_range);
	BIND_METHOD(is_using_sws);

	BIND_METHOD(get_y_data);
	BIND_METHOD(get_u_data);
	BIND_METHOD(get_v_data);
}

