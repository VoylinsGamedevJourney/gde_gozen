#!/bin/bash

scons -j10 target=template_debug platform=linux arch=x86_64 use_system=yes
scons -j10 target=template_debug platform=linux arch=x86_64 use_system=no enable_gpl=yes recompile_ffmpeg=yes
scons -j10 target=template_debug platform=windows arch=x86_64 use_system=no enable_gpl=yes recompile_ffmpeg=yes
