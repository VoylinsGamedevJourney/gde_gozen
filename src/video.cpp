#include "video.hpp"


//----------------------------------------------- STATIC FUNCTIONS
Dictionary Video::get_file_meta(String a_file_path) {
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

PackedStringArray Video::get_available_hw_devices() {
	PackedStringArray l_devices = PackedStringArray();
	enum AVHWDeviceType l_type = AV_HWDEVICE_TYPE_NONE;
	
	while ((l_type = av_hwdevice_iterate_types(l_type)) != AV_HWDEVICE_TYPE_NONE) {
		if (l_type != AV_HWDEVICE_TYPE_VULKAN) // At this moment no hardware support for Vulkan yet
			l_devices.append(av_hwdevice_get_type_name(l_type));
	}

	return l_devices;
}

enum AVPixelFormat Video::_get_format(AVCodecContext *a_av_ctx, const enum AVPixelFormat *a_pix_fmt) {
	Video* l_video = static_cast<Video*>(a_av_ctx->opaque);
    return l_video->_get_hw_format(a_pix_fmt);
}


//----------------------------------------------- NON-STATIC FUNCTIONS
int Video::open(String a_path, bool a_load_audio) {
	if (loaded) {
		UtilityFunctions::printerr("Video is already open");
		return -100;
	}

	path = a_path.utf8();
	_print_debug("Opening video file on path: " + path);

	// Allocate video file context
	av_format_ctx = avformat_alloc_context();
	if (!av_format_ctx) {
		UtilityFunctions::printerr("Couldn't allocate av format context!");
		return -1;
	}
	// Open file with avformat
	if (avformat_open_input(&av_format_ctx, path.c_str(), NULL, NULL)) {
		UtilityFunctions::printerr("Couldn't open video file!");
		close();
		return -1;
	}

	// Find stream information
	if (avformat_find_stream_info(av_format_ctx, NULL)) {
		UtilityFunctions::printerr("Couldn't find stream info!");
		close();
		return -1;
	}

	// Getting the audio and video stream
	_print_debug("Getting stream information ...");

	for (int i = 0; i < av_format_ctx->nb_streams; i++) {
		AVCodecParameters *av_codec_params = av_format_ctx->streams[i]->codecpar;

		if (!avcodec_find_decoder(av_codec_params->codec_id)) {
			av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_AUDIO) {
			if (a_load_audio && (response = _get_audio(av_format_ctx->streams[i])) != 0) {
				close();
				return response;
			}
			continue;
		} else if (av_codec_params->codec_type == AVMEDIA_TYPE_VIDEO) {
			av_stream_video = av_format_ctx->streams[i];
			resolution.x = av_codec_params->width;
			resolution.y = av_codec_params->height;

			if (av_codec_params->format != AV_PIX_FMT_YUV420P && hw_decoding) {
				UtilityFunctions::print("Hardware decoding not supported for this pixel format, switching to software decoding!");
				hw_decoding = false;
			}

			_print_debug("Video stream found.");
			continue;
		}
		av_format_ctx->streams[i]->discard = AVDISCARD_ALL;
	}

	// Setup Decoder codec context
	_print_debug("Setting up decoder codec context ...");

	const AVCodec *av_codec_video;
	if (hw_decoding)
		av_codec_video = _get_hw_codec();
	else 
		av_codec_video = avcodec_find_decoder(av_stream_video->codecpar->codec_id);

	if (!av_codec_video) {
		UtilityFunctions::printerr("Couldn't find any codec decoder for video!");
		close();
		return -3;
	}

	// Allocate codec context for decoder
	av_codec_ctx_video = avcodec_alloc_context3(av_codec_video);
	if (av_codec_ctx_video == NULL) {
		UtilityFunctions::printerr("Couldn't allocate codec context for video!");
		close();
		return -3;
	}

	if (hw_decoding && hw_device_ctx) {
		av_codec_ctx_video->hw_device_ctx = hw_device_ctx;

		for (int i = 0;; i++) {
			const AVCodecHWConfig* config = avcodec_get_hw_config(av_codec_video, i);
			if (!config) {
				UtilityFunctions::printerr("Current decoder does not accept selected device! Codec name: ", av_codec_video->long_name, "  -  Device: ", av_hwdevice_get_type_name(hw_decoder));

				hw_decoding = false;
				av_codec_ctx_video->hw_device_ctx = nullptr;
				break;
			}
			if ((config->methods & AV_CODEC_HW_CONFIG_METHOD_HW_DEVICE_CTX) && config->device_type == hw_decoder) {
				hw_pix_fmt = config->pix_fmt;

				_print_debug(std::string("Hardware pixel format is: ") + av_get_pix_fmt_name(hw_pix_fmt));
				break;
			}
		}

		av_codec_ctx_video->opaque = this;
		av_codec_ctx_video->get_format = _get_format;
	}

	// Copying parameters
	if (avcodec_parameters_to_context(av_codec_ctx_video, av_stream_video->codecpar)) {
		UtilityFunctions::printerr("Couldn't initialize video codec context!");
		close();
		return -3;
	}

	// Enable multi-threading for decoding - Video
	av_codec_ctx_video->thread_count = OS::get_singleton()->get_processor_count() - 1;
	if (av_codec_video->capabilities & AV_CODEC_CAP_FRAME_THREADS) {
		av_codec_ctx_video->thread_type = FF_THREAD_FRAME;
	} else if (av_codec_video->capabilities & AV_CODEC_CAP_SLICE_THREADS) {
		av_codec_ctx_video->thread_type = FF_THREAD_SLICE;
	} else av_codec_ctx_video->thread_count = 1; // Don't use multithreading
	
	// Open codec - Video
	if (avcodec_open2(av_codec_ctx_video, av_codec_video, NULL)) {
		UtilityFunctions::printerr("Couldn't open video codec!");
		close();
		return -3;
	}

	float l_aspect_ratio = av_q2d(av_stream_video->codecpar->sample_aspect_ratio);
	if (l_aspect_ratio > 1.0) 
		resolution.x = static_cast<int>(std::round(resolution.x * l_aspect_ratio));

	if (hw_decoding)
		pixel_format = av_get_pix_fmt_name(hw_pix_fmt);
	else 
		pixel_format = av_get_pix_fmt_name(av_codec_ctx_video->pix_fmt);

	_print_debug("Selected pixel format is: " + pixel_format);
	_print_debug("Seeking to beginning of video data ...");

	start_time_video = av_stream_video->start_time != AV_NOPTS_VALUE ? (long)(av_stream_video->start_time * stream_time_base_video) : 0;

	// Getting some data out of first frame
	av_packet = av_packet_alloc();
	av_frame = av_frame_alloc();
	if (!av_packet || !av_frame) {
		UtilityFunctions::printerr("Couldn't allocate packet or frame for video!");
		close();
		return -12;
	}

	if (hw_decoding) {
		av_hw_frame = av_frame_alloc();

		if (!av_hw_frame) {
			UtilityFunctions::printerr("Couldn't allocate hw frame for video!");
			close();
			return -12;
		}
	}

	avcodec_flush_buffers(av_codec_ctx_video);
	bool l_duration_from_bitrate = av_format_ctx->duration_estimation_method == AVFMT_DURATION_FROM_BITRATE;
	if (l_duration_from_bitrate) {
		UtilityFunctions::printerr("This video file is not usable!");
		close();
		return -5;
	}

	response = av_seek_frame(av_format_ctx, -1, start_time_video, AVSEEK_FLAG_BACKWARD);
	if (response < 0) {
		print_av_error("Seeking to beginning error: ");
		close();
		return -5;
	}

	int time = 0;
	if (debug) {
		_print_debug("Getting first frame ...");
		time = Time::get_singleton()->get_ticks_usec();
	}
	
	_get_frame(av_codec_ctx_video, av_stream_video->index);
	_print_debug("Getting first frame took: " + std::to_string(Time::get_singleton()->get_ticks_usec() - time));
	if (response) {
		print_av_error("Something went wrong getting first frame!");
		close();
		return -5;
	}
	
	_print_debug("Getting first frame info ...");

	// Checking for interlacing and what type of interlacing
	if (av_frame->flags & AV_FRAME_FLAG_INTERLACED)
		interlaced = av_frame->flags & AV_FRAME_FLAG_TOP_FIELD_FIRST ? 1 : 2;

	// Getting frame rate
	framerate = av_q2d(av_guess_frame_rate(av_format_ctx, av_stream_video, av_frame));
	if (framerate == 0) {
		UtilityFunctions::printerr("Invalid frame-rate for video found!");
		close();
		return -6;
	}

	// Setting variables
	average_frame_duration = 10000000.0 / framerate;								// eg. 1 sec / 25 fps = 400.000 ticks (40ms)
	stream_time_base_video = av_q2d(av_stream_video->time_base) * 1000.0 * 10000.0; // Converting timebase to ticks

	// Checking for variable framerate
	variable_framerate = av_codec_ctx_video->framerate.num == 0 || av_codec_ctx_video->framerate.den == 0;
	if (variable_framerate) {
		if (av_stream_video->r_frame_rate.num == av_stream_video->avg_frame_rate.num) {
			variable_framerate = false;
		} else {
			UtilityFunctions::printerr("Variable framerate detected, aborting! (not supported)");
			close();
			return -6;
		}
	}
	
	// Preparing the data array's
	if (!hw_decoding) {
		_print_debug("Preparing data array's for HW decoding with Shaders");
		y_data.resize(resolution.x * resolution.y);
		u_data.resize((resolution.x / 2) * (resolution.y / 2));
		v_data.resize((resolution.x / 2) * (resolution.y / 2));
	} else {
		_print_debug("Preparing data array's for SW decoding with Shaders");
		y_data.resize(resolution.x * resolution.y);
		u_data.resize((resolution.x / 2) * (resolution.y / 2) * 2);
	} 

	// Checking second frame
	_print_debug("Getting second frame ...");

	_get_frame(av_codec_ctx_video, av_stream_video->index);
	if (response)
		print_av_error("Something went wrong getting second frame!");

	_print_debug("Getting data from second frame ...");

	duration = av_format_ctx->duration;
	if (av_stream_video->duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
		if (duration == AV_NOPTS_VALUE || l_duration_from_bitrate) {
			UtilityFunctions::printerr("Video file is not usable!");
			close();
			return -7;
		} else {
			AVRational l_temp_rational = AVRational{1, AV_TIME_BASE};
			if (l_temp_rational.num != av_stream_video->time_base.num || l_temp_rational.num != av_stream_video->time_base.num)
				duration = std::ceil(static_cast<double>(duration) * av_q2d(l_temp_rational) / av_q2d(av_stream_video->time_base));
		}
		av_stream_video->duration = duration;
	}

	frame_duration = (static_cast<double>(duration) / static_cast<double>(AV_TIME_BASE)) * framerate;


	if (av_packet)
		av_packet_unref(av_packet);
	if (av_frame)
		av_frame_unref(av_frame);

	loaded = true;
	response = OK;

	_print_debug("Video is open now.");

	return OK;
}

void Video::close() {
	_print_debug("Closing video file on path: " + path);
	loaded = false;

	if (av_frame) av_frame_free(&av_frame);
	if (hw_decoding && av_hw_frame) av_frame_free(&av_hw_frame);
	if (av_packet) av_packet_free(&av_packet);

	if (av_codec_ctx_video) avcodec_free_context(&av_codec_ctx_video);
	if (av_format_ctx) avformat_close_input(&av_format_ctx);

	av_frame = nullptr;
	av_packet = nullptr;
	hw_device_ctx = nullptr;

	av_codec_ctx_video = nullptr;
	av_format_ctx = nullptr;
}

void Video::print_av_error(const char *a_message) {
	char l_error_buffer[AV_ERROR_MAX_STRING_SIZE];
	av_strerror(response, l_error_buffer, sizeof(l_error_buffer));
	UtilityFunctions::printerr((std::string(a_message) + " " + l_error_buffer).c_str());
}

int Video::_get_audio(AVStream* a_stream_audio) {
	audio = memnew(AudioStreamWAV);

	_print_debug("Getting audio ...");

	const AVCodec *l_codec_audio = avcodec_find_decoder(a_stream_audio->codecpar->codec_id);
	if (!l_codec_audio) {
		UtilityFunctions::printerr("Couldn't find any codec decoder for audio!");
		return -2;
	}

	AVCodecContext *l_codec_ctx_audio = avcodec_alloc_context3(l_codec_audio);
	if (l_codec_ctx_audio == NULL) {
		UtilityFunctions::printerr("Couldn't allocate codec context for audio!");
		return -2;
	} else if (avcodec_parameters_to_context(l_codec_ctx_audio, a_stream_audio->codecpar)) {
		UtilityFunctions::printerr("Couldn't initialize audio codec context!");
		return -2;
	}

	// Enable multi-threading for decoding - Audio
	// set codec to automatically determine how many threads suits best for the
	// decoding job
	l_codec_ctx_audio->thread_count = OS::get_singleton()->get_processor_count() - 1;
	if (l_codec_audio->capabilities & AV_CODEC_CAP_FRAME_THREADS) {
		l_codec_ctx_audio->thread_type = FF_THREAD_FRAME;
	} else if (l_codec_audio->capabilities & AV_CODEC_CAP_SLICE_THREADS) {
		l_codec_ctx_audio->thread_type = FF_THREAD_SLICE;
	} else l_codec_ctx_audio->thread_count =  1; // don't use multithreading

	l_codec_ctx_audio->request_sample_fmt = AV_SAMPLE_FMT_S16;

	_print_debug("Opening audio codec ...");

	// Open codec - Audio
	if (avcodec_open2(l_codec_ctx_audio, l_codec_audio, NULL)) {
		UtilityFunctions::printerr("Couldn't open audio codec!");
		return -2;
	}

	_print_debug("Creating SWR context ...");

	struct SwrContext *l_swr_ctx = nullptr;
	response = swr_alloc_set_opts2(
		&l_swr_ctx, &l_codec_ctx_audio->ch_layout, AV_SAMPLE_FMT_S16, l_codec_ctx_audio->sample_rate,
		&l_codec_ctx_audio->ch_layout, l_codec_ctx_audio->sample_fmt, l_codec_ctx_audio->sample_rate,
		0, nullptr);
	
	if (response < 0) {
		print_av_error("Failed to obtain SWR context!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		return -8;
	} 

	response = swr_init(l_swr_ctx);
	if (response < 0) {
		print_av_error("Couldn't initialize SWR!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		return -8;
	}

	_print_debug("Seeking to beginning of audio data ...");

	// Set the seeker to the beginning
	int start_time_audio = a_stream_audio->start_time != AV_NOPTS_VALUE ? a_stream_audio->start_time : 0;
	avcodec_flush_buffers(l_codec_ctx_audio);

	response = av_seek_frame(av_format_ctx, -1, start_time_audio, AVSEEK_FLAG_BACKWARD);
	if (response < 0) {
		UtilityFunctions::printerr("Can't seek to the beginning of audio stream!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		swr_free(&l_swr_ctx);
		return -9;
	}

	av_frame = av_frame_alloc();
	av_packet = av_packet_alloc();
	AVFrame *l_decoded_frame = av_frame_alloc();
	if (!av_frame || !av_packet || !l_decoded_frame) {
		UtilityFunctions::printerr("Couldn't allocate frames or packet for audio!");
		avcodec_flush_buffers(l_codec_ctx_audio);
		avcodec_free_context(&l_codec_ctx_audio);
		swr_free(&l_swr_ctx);
		return -11;
	}

	int l_bytes_per_samples = av_get_bytes_per_sample(AV_SAMPLE_FMT_S16);
	PackedByteArray l_audio_data = PackedByteArray();
    bool l_stereo = l_codec_ctx_audio->ch_layout.nb_channels >= 2;
	size_t l_audio_size = 0;

	_print_debug("Starting loop to gather audio data ...");

	while (true) {
		_get_frame(l_codec_ctx_audio, a_stream_audio->index);
		if (response)
			break;

		// Copy decoded data to new frame
		l_decoded_frame->format = AV_SAMPLE_FMT_S16;
		l_decoded_frame->ch_layout = av_frame->ch_layout;
		l_decoded_frame->sample_rate = av_frame->sample_rate;
		l_decoded_frame->nb_samples = swr_get_out_samples(l_swr_ctx, av_frame->nb_samples);

		response = av_frame_get_buffer(l_decoded_frame, 0);
		if (response < 0) {
			print_av_error("Couldn't create new frame for swr!");
			av_frame_unref(av_frame);
			av_frame_unref(l_decoded_frame);
			break;
		}

		response = swr_config_frame(l_swr_ctx, l_decoded_frame, av_frame);
		if (response < 0) {
			print_av_error("Couldn't config the audio frame!");
			av_frame_unref(av_frame);
			av_frame_unref(l_decoded_frame);
			break;
		}

		response = swr_convert_frame(l_swr_ctx, l_decoded_frame, av_frame);
		if (response < 0) {
			print_av_error("Couldn't convert the audio frame!");
			av_frame_unref(av_frame);
			av_frame_unref(l_decoded_frame);
			break;
		}
		
		size_t l_byte_size = l_decoded_frame->nb_samples * l_bytes_per_samples;
		if (l_codec_ctx_audio->ch_layout.nb_channels >= 2)
			l_byte_size *= 2;

		l_audio_data.resize(l_audio_size + l_byte_size);
		memcpy(&(l_audio_data.ptrw()[l_audio_size]), l_decoded_frame->extended_data[0], l_byte_size);
		l_audio_size += l_byte_size;

		av_frame_unref(av_frame);
		av_frame_unref(l_decoded_frame);
	}

	_print_debug("Audio object creation ...");

	// Audio creation
	audio->set_format(audio->FORMAT_16_BITS);
	audio->set_mix_rate(l_codec_ctx_audio->sample_rate);
	audio->set_stereo(l_stereo);
	audio->set_data(l_audio_data);

	// Cleanup
	avcodec_flush_buffers(l_codec_ctx_audio);
	avcodec_free_context(&l_codec_ctx_audio);
	swr_free(&l_swr_ctx);

	av_frame_free(&av_frame);
	av_frame_free(&l_decoded_frame);
	av_packet_free(&av_packet);

	_print_debug("Getting audio was succesfull.");

	return OK;
}

bool Video::seek_frame(int a_frame_nr) {
	if (!loaded) {
		UtilityFunctions::printerr("Video isn't open yet!");
		return false;
	}

	// Video seeking
	frame_timestamp = (long)(a_frame_nr * average_frame_duration);
	avcodec_flush_buffers(av_codec_ctx_video);

	response = av_seek_frame(av_format_ctx, -1, (start_time_video + frame_timestamp) / 10, AVSEEK_FLAG_BACKWARD);
	if (response < 0) {
		UtilityFunctions::printerr("Can't seek video file!");
		return false;
	}
	
	while (true) {
		_get_frame(av_codec_ctx_video, av_stream_video->index);
		if (response) {
			response = 1;
			UtilityFunctions::printerr("Problem happened getting frame in seek_frame! ", response);
			break;
		}

		// Get frame pts
		current_pts = av_frame->best_effort_timestamp == AV_NOPTS_VALUE ? av_frame->pts : av_frame->best_effort_timestamp;
		if (current_pts == AV_NOPTS_VALUE)
			continue;

		// Skip to actual requested frame
		if ((long)(current_pts * stream_time_base_video) / 10000 >= frame_timestamp / 10000) {
			_copy_frame_data();
			break;
		}
	}

	av_frame_unref(av_frame);
	av_packet_unref(av_packet);

	if (response == 1) {
		response = 0;
		return false;
	} else return true;
}

bool Video::next_frame(bool a_skip) {
	if (!loaded) {
		UtilityFunctions::printerr("Video isn't open yet!");
		return false;
	}

	_get_frame(av_codec_ctx_video, av_stream_video->index);

	if (!a_skip)
		_copy_frame_data();

	av_frame_unref(av_frame);
	av_packet_unref(av_packet);
	
	return true;
}

void Video::_get_frame(AVCodecContext *a_codec_ctx, int a_stream_id) {
	bool l_eof = false;

	while ((response = avcodec_receive_frame(a_codec_ctx, av_frame)) == AVERROR(EAGAIN) && !l_eof) {
		do {
			av_packet_unref(av_packet);
			response = av_read_frame(av_format_ctx, av_packet);
		} while (av_packet->stream_index != a_stream_id && response >= 0);

		if (response == AVERROR_EOF) {
			l_eof = true;
			avcodec_send_packet(a_codec_ctx, nullptr); // Send null packet to signal end
		} else if (response < 0) {
			UtilityFunctions::printerr("Error reading frame! ", response);
			break;
		} else {
			response = avcodec_send_packet(a_codec_ctx, av_packet);
			av_packet_unref(av_packet);
			if (response < 0) {
				UtilityFunctions::printerr("Problem sending package! ", response);
				break;
			}
		}
	}
}

void Video::_get_frame_audio(AVCodecContext *a_codec_ctx, int a_stream_id, AVFrame *a_frame, AVPacket *a_packet) {
	bool l_eof = false;

	while ((response = avcodec_receive_frame(a_codec_ctx, a_frame)) == AVERROR(EAGAIN) && !l_eof) {
		do {
			av_packet_unref(a_packet);
			response = av_read_frame(av_format_ctx, a_packet);
		} while (a_packet->stream_index != a_stream_id && response >= 0);

		if (response == AVERROR_EOF) {
			l_eof = true;
			avcodec_send_packet(a_codec_ctx, nullptr); // Send null packet to signal end
		} else if (response < 0) {
			UtilityFunctions::printerr("Error reading frame! ", response);
			break;
		} else {
			response = avcodec_send_packet(a_codec_ctx, a_packet);
			if (response < 0) {
				UtilityFunctions::printerr("Problem sending package! ", response);
				break;
			}
		}
	}
}

void Video::_copy_frame_data() {
	if (av_frame->format == hw_pix_fmt) {
		if (av_hwframe_transfer_data(av_hw_frame, av_frame, 0) < 0) {
			UtilityFunctions::printerr("Error transferring the frame to system memory!");
			return;
		}

		memcpy(y_data.ptrw(), av_hw_frame->data[0], y_data.size());
		memcpy(u_data.ptrw(), av_hw_frame->data[1], u_data.size());

		av_frame_unref(av_hw_frame);
		return;
	} else {
		memcpy(y_data.ptrw(), av_frame->data[0], y_data.size());
		memcpy(u_data.ptrw(), av_frame->data[1], u_data.size());
		memcpy(v_data.ptrw(), av_frame->data[2], v_data.size());
		return;
	}
}

const AVCodec *Video::_get_hw_codec() {
	const AVCodec *l_codec;
	AVHWDeviceType l_type = AV_HWDEVICE_TYPE_NONE;
	
	if (prefered_hw_decoder != "" && prefered_hw_decoder != "vulkan") {
		_print_debug("Getting prefered HW codec " + prefered_hw_decoder + " ...");

		l_type = av_hwdevice_find_type_by_name(prefered_hw_decoder.c_str());
		l_codec = avcodec_find_decoder(av_stream_video->codecpar->codec_id);

		// TODO: Support Vulkan, older hardware does not have video decoding support so this is not too necessary yet at this point.
		// const char *l_device_name = l_type == AV_HWDEVICE_TYPE_VULKAN ? RenderingServer::get_singleton()->get_video_adapter_name().utf8() : nullptr;
		// if (av_hwdevice_ctx_create(&hw_device_ctx, l_type, l_device_name, nullptr, 0) < 0)

        if ((response = av_hwdevice_ctx_create(&hw_device_ctx, l_type, nullptr, nullptr, 0)) < 0) {
			print_av_error("Selected hw device couldn't be created!");
		} else if (!av_codec_is_decoder(l_codec)) {
			UtilityFunctions::printerr("Found codec isn't a hw decoder!");
		} else {
			UtilityFunctions::print("Using HW decoder: ", av_hwdevice_get_type_name(l_type));
			hw_decoder = l_type;

			return l_codec;
		}
	}
    av_buffer_unref(&hw_device_ctx);

	_print_debug("Selecting best HW codec ...");

	l_type = AV_HWDEVICE_TYPE_NONE;
    while ((l_type = av_hwdevice_iterate_types(l_type)) != AV_HWDEVICE_TYPE_NONE) {
		// TODO: Support Vulkan, older hardware does not have video decoding support so this is not too necessary yet at this point.
		// const char *l_device_name = l_type == AV_HWDEVICE_TYPE_VULKAN ? RenderingServer::get_singleton()->get_video_adapter_name().utf8() : nullptr;
		// if (av_hwdevice_ctx_create(&hw_device_ctx, l_type, l_device_name, nullptr, 0) < 0)
		if (l_type == AV_HWDEVICE_TYPE_VULKAN)
			continue;

		l_codec = avcodec_find_decoder(av_stream_video->codecpar->codec_id);

        if (av_hwdevice_ctx_create(&hw_device_ctx, l_type, nullptr, nullptr, 0) < 0)
            continue;

        if (av_codec_is_decoder(l_codec)) {
			UtilityFunctions::print("Using HW decoder: ", av_hwdevice_get_type_name(l_type));
			hw_decoder = l_type;

			return l_codec;
		}
        av_buffer_unref(&hw_device_ctx);
	}

	hw_decoding = false;
	UtilityFunctions::print("HW decoding not possible, switching to software decoding!");
	return avcodec_find_decoder(av_stream_video->codecpar->codec_id);
}
 
enum AVPixelFormat Video::_get_hw_format(const enum AVPixelFormat *a_pix_fmt) {
	const enum AVPixelFormat *p;

    for (p = a_pix_fmt; *p != -1; p++) {
        if (*p == hw_pix_fmt) {
            return *p;
		}
    }

	UtilityFunctions::printerr("Failed to get HW surface format!");
    return AV_PIX_FMT_NONE;
}

void Video::_print_debug(std::string a_text) {
	if (debug)
		UtilityFunctions::print(a_text.c_str());
}

void Video::_printerr_debug(std::string a_text) {
	if (debug)
		UtilityFunctions::print(a_text.c_str());
}
