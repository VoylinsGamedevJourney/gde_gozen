# Encoding VP9 Videos with Alpha Channel Transparency

This guide explains how to encode VP9 videos with alpha channels for use in GoZen/Godot.

## Requirements

- **FFmpeg** with libvpx-vp9 support
- Source video with alpha channel (e.g., WebM with alpha, PNG sequence, etc.)

## Basic Encoding Command

```bash
ffmpeg -i input_with_alpha.webm \
  -c:v libvpx-vp9 \
  -pix_fmt yuva420p \
  -auto-alt-ref 0 \
  -b:v 2M \
  output_with_alpha.webm
```

## Parameter Explanation

- `-c:v libvpx-vp9` - Use VP9 codec (required for alpha support)
- `-pix_fmt yuva420p` - Use YUVA420P pixel format (YUV with alpha plane)
- `-auto-alt-ref 0` - Disable alternate reference frames (helps with alpha)
- `-b:v 2M` - Set video bitrate (adjust as needed)

## From PNG Sequence with Alpha

```bash
ffmpeg -framerate 30 -i frame_%04d.png \
  -c:v libvpx-vp9 \
  -pix_fmt yuva420p \
  -auto-alt-ref 0 \
  -b:v 2M \
  output_with_alpha.webm
```

## Quality Settings

### High Quality
```bash
-b:v 5M -crf 15 -quality good -speed 2
```

### Balanced
```bash
-b:v 2M -crf 30 -quality good -speed 4
```

### Fast Encoding (Lower Quality)
```bash
-b:v 1M -crf 40 -quality realtime -speed 6
```

## Verifying Alpha Channel

Check if your video has an alpha channel:

```bash
ffprobe -v error -select_streams v:0 -show_entries stream=pix_fmt -of default=noprint_wrappers=1:nokey=1 your_video.webm
```

Should output: `yuva420p`

## Using in Godot with GoZen

Once encoded, simply load the video in Godot:

```gdscript
var video_playback = GoZenVideoPlayback.new()
video_playback.open("res://path/to/your_video_with_alpha.webm")
add_child(video_playback)
```

The alpha channel will automatically be detected and rendered with transparency, similar to PNG sprites.

## Alpha Channel Convention

- **0 (black)** = Fully transparent
- **255 (white)** = Fully opaque
- Values in between = Partial transparency

## Troubleshooting

**Problem**: Video shows black background instead of transparency
- Verify pixel format is `yuva420p` using ffprobe
- Check that source material actually has alpha channel
- Ensure you're using libvpx-vp9 codec (not native vp9)

**Problem**: Video plays but looks wrong
- Try different quality settings
- Check color space/range settings in GoZen
- Verify source video plays correctly in media player that supports alpha

## Performance Notes

- VP9 with alpha has higher decode overhead than regular VP9
- Consider video resolution and bitrate for your target platform
- Thread count is automatically capped at 16 for optimal performance
