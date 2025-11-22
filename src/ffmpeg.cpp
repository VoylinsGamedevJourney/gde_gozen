#include "ffmpeg.hpp"



void FFmpeg::print_av_error(const char* a_message, int a_error) {
	char l_error_buffer[AV_ERROR_MAX_STRING_SIZE];

	av_strerror(a_error, l_error_buffer, sizeof(l_error_buffer));
	UtilityFunctions::printerr((std::string(a_message) + " " + l_error_buffer).c_str());
}

void FFmpeg::enable_multithreading(AVCodecContext* a_codec_ctx, const AVCodec* a_codec) {
	a_codec_ctx->thread_count = OS::get_singleton()->get_processor_count() - 1;
	if (a_codec->capabilities & AV_CODEC_CAP_FRAME_THREADS)
		a_codec_ctx->thread_type = FF_THREAD_FRAME;
	else if (a_codec->capabilities & AV_CODEC_CAP_SLICE_THREADS)
		a_codec_ctx->thread_type = FF_THREAD_SLICE;
	else
		a_codec_ctx->thread_count = 1; // Don't use multithreading
}

int FFmpeg::get_frame(AVFormatContext* a_format_ctx, AVCodecContext* a_codec_ctx, int a_stream_id, AVFrame* a_frame,
					  AVPacket* a_packet) {
	eof = false;

	av_frame_unref(a_frame);
	while ((response = avcodec_receive_frame(a_codec_ctx, a_frame)) == AVERROR(EAGAIN) && !eof) {
		do {
			av_packet_unref(a_packet);
			response = av_read_frame(a_format_ctx, a_packet);
		} while (a_packet->stream_index != a_stream_id && response >= 0);

		if (response == AVERROR_EOF) {
			eof = true;
			avcodec_send_packet(a_codec_ctx, nullptr); // Send null packet to signal end
		} else if (response < 0) {
			UtilityFunctions::printerr("Error reading frame! ", response);
			break;
		} else {
			response = avcodec_send_packet(a_codec_ctx, a_packet);
			if (response < 0 && response != AVERROR_INVALIDDATA) {
				UtilityFunctions::printerr("Problem sending package! ", response);
				break;
			}
		}
		av_frame_unref(a_frame);
	}

	return response;
}

enum AVPixelFormat FFmpeg::get_hw_format(const enum AVPixelFormat* a_pix_fmt, enum AVPixelFormat* a_hw_pix_fmt) {
	const enum AVPixelFormat* p;

	for (p = a_pix_fmt; *p != -1; p++)
		if (*p == *a_hw_pix_fmt)
			return *p;

	UtilityFunctions::printerr("Failed to get HW surface format!");
	return AV_PIX_FMT_NONE;
}

// For `res://` videos.
int FFmpeg::read_buffer_packet(void* opaque, uint8_t* buffer, int buffer_size) {
	BufferData* buffer_data = (BufferData*)opaque;
	size_t remaining = buffer_data->size - buffer_data->offset;

	if (remaining == 0)
		return AVERROR_EOF;

	// Change buffer size if not enough data remaining.
	size_t new_size = (remaining < (size_t)buffer_size ? remaining : (size_t)buffer_size);

	memcpy(buffer, buffer_data->ptr + buffer_data->offset, new_size);
	buffer_data->offset += new_size;
	return (int)new_size;
}

// For `res://` videos.
int64_t FFmpeg::seek_buffer(void* opaque, int64_t offset, int where) {
	BufferData* buffer_data = (BufferData*)opaque;
	int64_t new_offset = 0;

	switch (where) {
	case SEEK_SET: // 0
		new_offset = offset;
		break;
	case SEEK_CUR: // 1
		new_offset = buffer_data->offset + offset;
		break;
	case SEEK_END: // 2
		new_offset = buffer_data->size + offset;
		break;
	case AVSEEK_SIZE: // 1
		return buffer_data->size;
	default: // Error
		return -1;
	}

	if (new_offset < 0)
		return -1;

	buffer_data->offset = new_offset;
	return buffer_data->offset;
}
