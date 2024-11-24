# GDE GoZen error codes

## Video class

### get_video_file_meta

No error code but returns an empty dictionary when nothing was able to be read.

### open

- 0: OK;
- -1: Couldn't open video file; 
- -2: Failed setting up of audio decoder;
- -3: Failed setting up of video decoder;
- -4: Failed setting up SWS;
- -5: Video file is not usable due to limitations;
- -7: Could not establish the total amount of frames in video files;
- -8: Failed setting up of SWR; 
- -9: Audio seeking error;
- -10: Hardware decoder setup failed;
- -11: Couldn't allocate audio frames or packet;
- -12: Couldn't allocate video frame or packet;
- -13: Couldn't allocate video frame for hw decoding;
- -14: Unsupported format;
- -100: Video already open;

### seek_frame and next_frame

No error code but returns an empty picture when an error occured.

## Renderer class

### open

- 0: OK;
- -1: Renderer not fully ready (some variables aren't set);
- -2: Path is not set;
- -3: Video codec not set;
- -4: Failed to open file for writing;
- -5: Failed to setup video codec;
- -6: Failed to setup video stream;
- -7: Failed to open video codec;
- -8: Failed to allocate av packet and/or av frame;
- -9: Failed to copy video params;
- -10: Failed to open output file;
- -11: Failed to write headers;
- -12: Failed to create SWS context;

### send_frame

- 0: OK;
- -1: Audio codec is set but audio isn't added yet;
- -2: Video codec isn't open;
- -3: Frame is not write-able;
- -4: Failed to convert image data;
- -5: Failed to send frame to encoder; 
- -6: Renderer isn't open;

Any other response is an FFmpeg error code which has to do with sending, receiving, and writing frames.

### send_audio

- 0: OK;
- -1: Audio codec not set;
- -2: Audio already added;
- -3: Failed to setup audio stream;
- -4: Failed to find audio codec;
- -5: Failed to allocate audio codec context;
- -6: Renderer isn't open;
- -7: Failed to allocate packet and/or frame;
- -8: Failed to copy channel layout;
- -9: Failed to get frame buffer;
- -10: Failed to make frame writable;
- -11: Error sending frame to encoder;
- -12: Error encoding audio frame;
- -13: Error writing packet;

### close

- 0: OK;
- -1: Codec is not open;

