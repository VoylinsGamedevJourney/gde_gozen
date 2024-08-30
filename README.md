[![Linux build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_release.yml) [![Linux full build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_full_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_linux_full_release.yml) [![Windows Build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_windows_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/build_gdextension_windows_release.yml) [![Check Linux full build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/check_gdextension_linux_full_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/check_gdextension_linux_full_release.yml) [![Check Windows build](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/check_gdextension_windows_release.yml/badge.svg)](https://github.com/VoylinsGamedevJourney/gde_gozen/actions/workflows/check_gdextension_windows_release.yml)
[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R4M1UM6)

# GDE_GoZen

GDE GoZen is part of the GoZen project, a video editor made with Godot, which works thanks to FFmpeg! This GDExtension for Godot provides functionality for video and audio playback. This GDExtension is mainly available as an addon through my [ko-fi page](https://ko-fi.com/s/c6ec85052b) and [itch.io](https://voylin.itch.io/gde-gozen_video-playback-addon-for-godot)   Since version 2 we also have video rendering capabilities. These are still something which need some work and improvements, which will happen over time as the progress of GoZen, our video editor made in Godot, becomes more and more advanced.

## Compiling the GDExtension

For all compiling information you can go to [Compiling info readme](https://github.com/VoylinsGamedevJourney/gde_gozen/blob/master/COMPILE_INFO.md).

## Usage of the GDExtension

For information of how to use this GDExtension, you can do to the [Usage info readme](https://github.com/VoylinsGamedevJourney/gde_gozen/blob/master/USAGE_INFO.md). The addon build also comes with information on how to use the GDExtension.

## Licensing

Please be careful and read up on the licensing of FFmpeg. If you want access to all video codecs and features, you'll have to use the GPL 3.0 license for your project. Licensing is complicated and I'm not a lawyer, we removed the --enable-gpl flag so the binaries are LGPL, but you can add that flag after '.configure' in the SCons file. Both us and FFmpeg can not be blamed for these licensing rules, blame the big (money hungry) companies with their (ridiculous) patents. 

> This software uses libraries from the FFmpeg project under the LGPLv2.1

