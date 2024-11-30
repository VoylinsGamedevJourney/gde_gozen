# GDE GoZen error codes

This is a list of all possible error codes which may be returned from each function from each class. All error codes are part of GoZenError and you can use the static `print_error(Error a_err)` function of the GoZenError class to print more feedback.

Most of these errors are pretty self-explanatory.

## Video class

### open
- OK;

Video file related errors:
- ERR_ALREADY_OPEN_VIDEO;
- ERR_OPENING_VIDEO;
- ERR_INVALID_VIDEO: Unsupported format;
- ERR_INVALID_FRAMERATE: Framerate is 0;

FFmpeg related errors:
- ERR_CREATING_AV_FORMAT_FAILED;
- ERR_NO_STREAM_INFO_FOUND;
- ERR_SEEKING;

- ERR_FAILED_FINDING_VIDEO_DECODER;
- ERR_FAILED_ALLOC_VIDEO_CODEC;
- ERR_FAILED_INIT_VIDEO_CODEC;
- ERR_FAILED_OPEN_VIDEO_CODEC;

- ERR_FAILED_ALLOC_PACKET;
- ERR_FAILED_ALLOC_FRAME;

### seek_frame and next_frame

- OK;
- ERR_NOT_OPEN: Video file isn't open yet;
- ERR_SEEKING;

## Audio class

The audio class returns an empty audio stream on error, but the error int can get gotten through the static `get_error()` function from the audio class.

- OK;
- ERR_CREATING_AV_FORMAT_FAILED;
- ERR_OPENING_AUDIO;
- ERR_NO_STREAM_INFO_FOUND;

## Renderer class

### open

- OK;
- ERR_OPENING_VIDEO;
- ERR_NO_PATH_SET;
- ERR_ALREADY_OPEN_RENDERER;

- ERR_CREATING_AV_FORMAT_FAILED;
- ERR_FAILED_CREATING_STREAM;
- ERR_FAILED_ALLOC_PACKET;
- ERR_FAILED_ALLOC_FRAME;
- ERR_GET_FRAME_BUFFER;
- ERR_COPY_STREAM_PARAMS;
- ERR_FAILED_CREATING_STREAM;
- ERR_WRITING_HEADER;

- ERR_NO_CODEC_SET_VIDEO;
- ERR_FAILED_OPEN_VIDEO_CODEC;
- ERR_FAILED_ALLOC_VIDEO_CODEC;
- ERR_FAILED_OPEN_VIDEO_CODEC;

- ERR_FAILED_FINDING_AUDIO_ENCODER;
- ERR_FAILED_ALLOC_AUDIO_CODEC;
- ERR_FAILED_OPEN_AUDIO_CODEC;

- ERR_CREATING_SWS;

### send_frame

- OK;
- ERR_NOT_OPEN_RENDERER;
- ERR_AUDIO_NOT_SEND;

- ERR_FAILED_OPEN_VIDEO_CODEC;
- ERR_FAILED_SENDING_FRAME;
- ERR_FRAME_NOT_WRITABLE;
- ERR_ENCODING_FRAME;

- ERR_SCALING_FAILED;

### send_audio

- OK;
- ERR_NOT_OPEN_RENDERER;
- ERR_FAILED_ALLOC_FRAME;
- ERR_FAILED_ALLOC_PACKET;
- ERR_FAILED_SENDING_FRAME;
- ERR_ENCODING_FRAME;
- ERR_FAILED_FLUSH;

- ERR_CREATING_SWR;
- ERR_FAILED_RESAMPLE;

- ERR_AUDIO_NOT_ENABLED;
- ERR_AUDIO_ALREADY_SEND;
