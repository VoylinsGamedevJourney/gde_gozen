[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R4M1UM6) 
[![Linux](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_linux.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_linux.yml) [![Build GDE GoZen - Windows](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_windows.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_windows.yml)  [![MacOS](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_macos.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_macos.yml)

<img src="./assets/icon.svg" alt="GoZen Logo" width="300"/>

# GDE_GoZen

GDE GoZen is part of the [GoZen project](https://github.com/VoylinsGamedevJourney/GoZen), a video editor made with Godot! This GDExtension for Godot provides functionality for video playback and seeking. Since version 4.1 we also have working video rendering capabilities. This repo gets updated quite often as I'm improving performance and adding features/functionality. Changes will occur at a regular pace whilst working on my video editor, [GoZen](https://github.com/VoylinsGamedevJourney/GoZen).

## Current support

- Godot version: 4.3+
- OS support: Linux & Windows

Work is being done to support MacOS and Android. But due to time and/or hardware limitations, it may take some time to get proper support for these platforms. There won't be a web export for some time due to limitations with FFmpeg.

## Download compiled version
The addon is available on [my ko-fi page](https://ko-fi.com/s/c6ec85052b) and on [itch.io](https://voylin.itch.io/gde-gozen-video-playback-addon-for-godot). Source code will always be available for free so you can technically compile everything yourself, but if you also want to support the work which I've put into this GDExtension and the future work which I'll put into this I'd really appreciate it if you would get the compiled version from my ko-fi page.

At this moment the GDExtension is only supporting **Godot 4.3+**. Changing some of the static typed variables may make it possible to be used in other Godot 4.0+ version but this is not tested and possible support for older versions may not come. Also as mentioned above, there is only Linux and Windows support at this moment!

## Compiling the GDExtension

Feeling more adventurous and want to compile by yourself? For all compiling information you can go to [Compiling info readme](https://github.com/VoylinsGamedevJourney/gde_gozen/blob/master/COMPILE_INFO.md).

## Usage of the GDExtension

For information of how to use this GDExtension, you can go to the [Usage info readme](https://github.com/VoylinsGamedevJourney/gde_gozen/blob/master/USAGE_INFO.md). The addon build also comes with a README which contains information on how to use the GDExtension.

## Licensing

Please be careful and read up on the licensing requirements of both this repo and of FFmpeg when using this GDExtension. If you want access to all video codecs and features, you'll have to use the GPL 3.0 license for your project, this is especially important when wanting to use the rendering capabilities of this GDExtension. Licensing is complicated and I'm not a lawyer. When building the GDExtension you'll be asked if you want the GPL build or not. For commercial projects of which the code is not open source, don't use GPL. If your project is open source and under the GPL license, you can use the GPL build.

> This software uses libraries from the FFmpeg project under the LGPLv2.1

