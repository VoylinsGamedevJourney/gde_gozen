# How to use GDE GoZen

Using this GDExtension is not as straightforward as just putting it into your project, selecting a playback node and finished. This plugin is mainly intended for using inside of the GoZen video editor but as you can see in the test_room you can use it perfectly fine for video playback. Please look at the test room project and this document before submitting issues or asking unnecessary questions in the Discord server.

## The .gdextension file

This file is an easy one, choose where you want to save the binary files and adjust to your situation and style:

```
[configuration]

entry_symbol = "gozen_library_init"
compatibility_minimum = "4.2"
reloadable = true

[libraries]

linux.debug.x86_64 = "res://../bin/linux/libgozen.linux.template_debug.dev.x86_64.so"
linux.release.x86_64 = "res://../bin/linux/libgozen.linux.template_release.x86_64.so"
windows.debug.x86_64 = "res://../bin/windows/libgozen.windows.template_debug.dev.x86_64.dll"
windows.release.x86_64 = "res://../bin/windows/libgozen.windows.template_release.x86_64.dll"
```

As for how I handle the binary files, they are outside of the main Godot project.

## Video playback

Initialize a variable of Video and you are good to go following the documentation below.

#### Getting video file meta

**__Moved to this class from the Renderer class starting from the commits which happened after V2.0 release!__**

This function, `get_video_file_meta()` is to check if a video file has been renderer successfully. Note that this function **will be dissapearing in future version** and will become a part of video playback instead. This is just here for testing if the video rendered successfully.

### Opening a video

For opening a video use `open_video(FILE_PATH, BOOL_VALUE)`. The file path is the full path to the video file and the bool value is for if you want to load the audio or not. The reason for that bool value is related to GoZen as we need to load a video for every clip for seeking to work but this is not necessary for the audio.

### Closing the video

`close_video()` is important to free the memory! Whenever you don't need it anymore you can or free the class, or run close_video allowing you to open another video afterwards in the same class instance

### Checking video file

To know if the video file is still open or if it opened in the first place, use `is_video_open()`. Trying to seek frames or getting the next frame may result in crashing.

### Seeking frames

Seeking frames is easy to do with `seek_frame(FRAME_NR)`, this will return an image variable with the frame data. Seeking frames is process heavy so whenever possible, use next_frame. If the next frame which you want to display is about 20-30 frames after the frame you used for seek_frame, just use next_frame for that amount of times as performance will still be faster. This is also depending on how small your video file is. If you video is smaller than a minute, seek_frame will not have too much of a performance cost.

### Next frame

After seeking you may want to get the next frame in line, this is also easy to do with `next_frame()`, this will return an image variable with the frame data. This function is less processer and memory intensive. The Video class will be waiting at the frame which it last showed, so next_frame will give the next one in line.

### Getting audio

The audio is loaded at startup and is stored inside of a variable inside the video class. To get access to this use `get_audio()` which will return and AudioStreamWAV.

### Get framerate

`get_framerate()` is useful so you know how fast or slow you need to present certain frames. You can use a function like this to check when the next frame needs to be shown:
```
func _process(a_delta) -> void:
	time_elapsed += a_delta
	if time_elapsed < frame_time:
		return
		
	while time_elapsed >= frame_time:
		time_elapsed -= frame_time
		current_frame += 1
    ... # Show or next frame or seek frame depending on how many frames have passed
```

### Checking for Variable Framerate

Variable framerate is something which is causing issues and is not properly supported (as of yet), for this use `is_framerate_variable()` to check if the video has VFR or not.

### Getting total length of video

Getting the total length is not supported but `get_total_frame_nr()` is something you can use for achieving this. Just take this value and do it times the framerate to calculate the total. Getting the total number of frames is important so you don't try to get the next frame past a point of where no more frames are available as this ccan result in crashing.

## Renderer

> [!Caution]
> The renderer is incomplete as we still need Audio rendering to be implemented, this part will come in version 3 as this is also needed for the main project, GoZen.

For starting to render use the Renderer class and following the instructions here. First set all necessary variables and then run the functions accordingly.

### Supported codecs

Technically since we use FFmpeg we have access to all their codecs, but many of these are not that common and I don't feel like testing every single one of them. If you have a codec which you think should be supported, let me know by creating an issue!

The enum values start with `A_` for audio codecs, `V_` for video codecs, and `S_` for subtitle codecs.

#### Audio codecs

As mentioned already, audio exporting is not working yet, but these will be the codecs which I'll try to give support to:

- MP3;
- AAC;
- OPUS;
- VORBIS;
- FLAC;
- PCM_UNCOMPRESSED;
- AC3;
- EAC3;
- WAV;
- MP2;

#### Video codecs

Not all of these formats have been tested yet but should be working:

- H264;
- HEVC; (Which is basically H265)
- VP9;
- MPEG4;
- MPEG2;
- MPEG1;
- AV1;
- VP8;
- AMV;
- GOPRO_CINEFORM;
- CINEPAK;
- DIRAC;
- FLV1;
- GIF;
- H261;
- H263;
- H263p;
- THEORA;
- WEBP;
- DNXHD;
- MJPEG;
- PRORES;
- RAWVIDEO;
- YUV4;

#### Subtitle codecs

Subtitles aren't implemented yet, they also won't be for some time but I've allready made the enums for the ones I am planning on probably supporting. Note that some of these may be removed later on if they appear to be too much of a pain to implement.

- ASS;
- MOV_TEXT;
- SUBRIP;
- TEXT;
- TTML;
- WEBVTT;
- XSUB;

### Setters and getters

Before opening the renderer with the function `open()`, please make certain that all variables are set properly as changing them after opening the renderer won't change anything!

#### Getting supported codecs

Using the functin `get_supported_codecs()` will give you a dictionary of all supported codecs and if they have hardware support or not. Take in mind that this is only for encoding. There is no function yet which will tell you if there is hardware support for decoding!

This function returns a dictionary with the following structure:
```
{ 
    "audio": {
        "MP3": {"supported": BOOL_VALUE, "codec_id": INT_VALUE, "hardware_accel": BOOL_VALUE},
        ...
    },
    "video": {
        "H264": {"supported": BOOL_VALUE, "codec_id": INT_VALUE, "hardware_accel": BOOL_VALUE},
        ...
    }
}
```

#### Is video codec supported

`is_video_codec_supported(VIDEO_CODEC_ENUM)` is for when you want to check against a single codec if there is encoding support for it or not.

#### Is audio codec supported

`is_audio_codec_supported(AUDIO_CODEC_ENUM)` is for when you want to check against a single codec if there is encoding support for it or not.

#### Getting video file meta

**__Moved to the Video class starting from the commits which happened after V2.0 release!__**

This function, `get_video_file_meta()` is to check if a video file has been renderer successfully. Note that this function **will be dissapearing in future version** and will become a part of video playback instead. This is just here for testing if the video rendered successfully.

#### Set/Get output file

Before running open, set the path of where you want your file to be saved, for this you can use:
`set_output_file_path(FILE_PATH)` and for getting the value `get_output_file_path()`.

Without a valid path the renderer will refuse to open with `open()`.

#### Set/Get video codec

`set_video_codec(VIDEO_CODEC_ENUM)` should be used for setting the video encoder codec. For getting the value `get_video_codec()` can be used.

#### Set/Get audio codec

`set_audio_codec(AUDIO_CODEC_ENUM)` should be used for setting the audio encoder codec. For getting the value `get_audio_codec()` can be used.
Note that for this one you will need to enable audio rendering by using `set_render_audio(VALUE)`.

#### Enabling audio rendering

Without using `set_render_audio(BOOL_VALUE)`, audio may or may not render out with your video. This value can be checked with `get_render_audio()`.

#### Set/Get the resolution

For setting the resolution use method `set_resolution(RESOLUTION)`, note that the value should be of Vector2i. For getting this value use `get_resolution()`.

#### Set/Get the framerate

By default this is 30, it is a float value and can be set with `set_framerate(FLOAT_VALUE)`, for getting the value use `get_framerate()`.

#### Set/Get bit rate

The bit rate should be set with `set_bit_rate(INT_VALUE)`. Do take in mind that the submitted value is in bits, so for 5000Kbs you would need to do 5000 * 1000 to set the correct bit rate. `get_bit_rate()` can be used to get this value.

#### Set/Get gop size

Gop means Group of Pictures. This is mainly for improving video seeking and controlling the file size. Look up more about GOP if you need more info on how to set this. A recommended amount is 10, but can be set to 0. For some codecs this won't have an effect.

`set_gop_size(INT_VALUE)` is used for setting this variable and `get_gop_size()` for checking the value.

#### Checking if rendering is possible

`ready_check()` can be used to see if all variables are properly set. At this moment this won't inform you yet of which variables haven't been set properly, this may be implemented in the future, but probably now.

### Actually rendering a video

When you have set all the value's for how to render the video, use `open()` to open up all the codec context info and such to start accepting data. For sending images to put into the video use `send_frame(IMAGE)`, do this in order as there is no way to specifcy for which frame you want this frame to be.

**Audio isn't working yet** but as it is less hard on ram you should send the entire audio data at once to `send_audio(AUDIO_DATA)`.

When all data has been submitted you can use `close()` to close the renderer and to finalize the video.

## Exporting godot projects with the gde

> [!Warning]
> When exporting, be certain that you take the extra binary files from FFmpeg and add them to the export files as only the gdextension binary will be copied in the same folder as your exported project!

Other then the warning mentioned above, exporting should be pretty straightforward.
