[![Linux build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_release.yml) [![Linux full build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_full_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_full_release.yml) [![Windows Build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_windows_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_windows_release.yml) [![Video editor build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/video_editor_build.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/video_editor_build.yml)

# GDE_GoZen

GDE GoZen is the core of GoZen which works thanks to FFmpeg! This GDExtension for Godot provides functionality for video and audio playback. Since version 2 we also have video rendering capabilities. These are still something which need some work and improvements, which will happen over time as the progress of GoZen, our video editor made in Godot, becomes more and more advanced.

## Compiling the GDExtension

For all compiling information you can go to [Compiling info readme](https://github.com/VoylinsGamedevJourney/gde_gozen/blob/master/COMPILE_INFO.md).

## Usage of the GDExtension

For information of how to use this GDExtension, you can do to the [Usage info readme](https://github.com/VoylinsGamedevJourney/gde_gozen/blob/master/USAGE_INFO.md).

## Road-map for Version 3

Version 2 got released on 2024-08-02 and included the rendering update. For version 3 we will be focussing on separating the rendering code from the video playback code so people who want video playback don't need unnecessary code inside of their projects. For the road map of this GDExtension we will keep it simple as we have a lot of it already working, except audio for the rendering system. But version 2 is more than usable for most use cases.

Interlacing/De-interlacing support is something which could be helpful, but I don't have enough knowledge about that to work on it. So not certain if this would even make it into version 3, unless there would be support from other people who do have knowledge of this.

Variable frame-rate videos is something I wish we could support, but all other video editors are struggling with that as well, so this one man team won't be tackling implementing this. 

## Biggest priority

My biggest priority for this GDExtension is still to make it work with the video editor, GoZen. The main reason of sharing it here is to provide some extra solutions to people who are wanting to have video playback inside of their Godot projects.

## Licensing

Please be careful and read up on the licensing of FFmpeg. If you want access to all video codecs and features, you'll have to use the GPL 3.0 license for your project. Licensing is complicated and I'm not a lawyer, we removed the --enable-gpl flag so the binaries are LGPL, but you can add that flag after '.configure' in the SCons file. Both us and FFmpeg can not be blamed for these licensing rules, blame the big (money hungry) companies with their (ridiculous) patents. 
> This software uses libraries from the FFmpeg project under the LGPLv2.1
