#pragma once

#include <godot_cpp/classes/audio_stream_wav.hpp>
#include <godot_cpp/classes/control.hpp>
#include <godot_cpp/classes/image_texture.hpp>
#include <godot_cpp/variant/utility_functions.hpp>
#include <godot_cpp/classes/rendering_server.hpp>

#include "ffmpeg.hpp"


using namespace godot;

class Audio : public Resource {
	GDCLASS(Audio, Resource);

public:
	inline void enable_debug() { av_log_set_level(AV_LOG_VERBOSE); }

	static AudioStreamWAV *get_wav(String a_path);


protected:
	static inline void _bind_methods() {
		ClassDB::bind_static_method("Audio", D_METHOD("get_wav", "a_file_path"), &Audio::get_wav);
	}
};
