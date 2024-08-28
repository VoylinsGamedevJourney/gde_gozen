# GDE GoZen error codes

## Video class

### get_video_file_meta

No error code but returns an empty dictionary when nothing was able to be read.

### open

- 0: OK;
- -1: Couldn't open video file; 
- -2: Failed setting up of audio decoder;
- -3: Failed setting up of video decoder;
- -4: Unsupported pixel format;
- -5: Video file is not usable due to limitations;
- -6: Invalid frame-rate found in video;
- -7: Could not establish the total amount of frames in video files;
- -8: Failed setting up of SWR; 
- -9: Audio seeking error;

### seek_frame and next_frame

No error code but returns an empty picture when an error occured.

## Renderer class

### open

- 0: OK;
- -1: Renderer not fully ready (some variables aren't set);
- -2: Failed to open video context;
- -3: Failed to setup video encoder; 
- -4: failed to setup audio encoder;
- -5: Failed to setup video stream;
- -6: Failed to setup audio stream;
- -7: Couldn't create packet;
- -8: Couldn't create frame;
- -10: Couldn't create SWR;
- -11: Failed to open video file;
- -12: Failed to write stream header;

### send_frame

- 0: OK;
- -1: Video codec isn't open;
- -2: Frame is not write-able;
- -3: Couldn't send frame to encoder; 

Any other response is an FFmpeg error code which has to do with sending, receiving, and writing frames.

### send_audio

- 0: OK;
- -1: Audio rendering is not enabled;
- -2: Audio codec isn't open;

### close

- 0: OK;
- -1: Codec is not open;

