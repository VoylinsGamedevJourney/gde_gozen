# Compiling GDEGoZen

Compiling this GDExtension can be done in 2 different way's, using the python file `build.py` or by using the command line.

> [!IMPORTANT]
> At this moment only Linux and Windows are supported!

## Using build.py

Pretty straight forward, just run the script and enter the numbers of the selection you want. There is an option for using the system FFmpeg, if the system does not have FFmpeg installed (Version 6+) you should not use the system install and you'll have to compile FFmpeg libraries from scratch to accompany the GDExtension file. For Windows you don't have a choice as the FFmpeg libraries need to be included for it to work.

## Using the command line

Using the command line is pretty straightforward. Use `scons` with any of the stuff you want afterwards:

### Multi-threaded compiling

`-j` directly followed by the amount of cores/threads which you want to use for compiling.

### Target

`target=` is specificially for Godot, so use or `template_debug` or `template_release`.

### Platform

`platform=` followed by eather `linux` or `windows` as at this moment MacOS isn't supported.

### Architecture

`arch=` is a bit more difficult, but will generally be `x86_64` as this is for 64 bit systems which most pc's are running, for 32 bit systems use `x86_32`. However there is also `arm64` and `arm32` for arm based systems. There is also `rv64` for Linux systems which you probably won't need anytime soon.

### Extra arguments

#### Linux: Use system FFmpeg

`use_system=` is talking about the FFmpeg install on your system. This is only required for Linux builds, default is to use the system FFmpeg (this only works when the FFmpeg which is installed is over version 6). If you want to include the FFmpeg libraries you'll need to set this to `no`, else don't use this tag or say `yes`. 

### Enable GPL

`enable_gpl=` set to `yes` or `no`. Some codecs and extra features need GPL to be enabled. For GoZen we will have this enabled as GoZen is a GPL licensed project. But when you want to have a closed source version it'll be better to leave this off. Default is `no`.

### Include Renderer

`include_renderer=` with `yes`, the rendering class will get included. If you don't need rendering capabilities, you could use set this to `no`. Default is `no`.

### Recompile FFmpeg

`recompile_ffmpeg=` is set to yes by default, but when making consequential builds, you probably don't need this to happen so for the second run of the same OS you could set this to `no`. This is helpful when building the template_debug and template_release directly after each other.

### Enable small

`enable_small=` is a command which will make FFmpeg take longer to compile but will save in space as the libraries will be smaller in size. Set this to `yes` to use it.
