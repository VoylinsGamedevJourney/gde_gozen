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

