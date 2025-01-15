#!/usr/bin/env python
import os
import platform as os_platform
import time


LIBS_COMMON = [
    'avcodec',
    'avformat',
    'avdevice',
    'avutil',
    'swresample',
    'swscale']
SLEEP_TIME = 2
LOCATION = "test_room/addons/gde_gozen/bin"


env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])

jobs = ARGUMENTS.get('jobs', 4)
platform = ARGUMENTS.get('platform', 'linux')



if 'linux' in platform:
    os.makedirs(f'{LOCATION}/{platform}', exist_ok=True)

    env.Append(
        LINKFLAGS=['-static-libstdc++'],
        CPPFLAGS=[
            '-Iffmpeg/bin',
            '-Iffmpeg/bin/include'],
        LIBPATH=[
            'ffmpeg/bin/include/libavcodec',
            'ffmpeg/bin/include/libavformat',
            'ffmpeg/bin/include/libavdevice',
            'ffmpeg/bin/include/libavutil',
            'ffmpeg/bin/include/libswresample',
            'ffmpeg/bin/include/libswscale',
            'ffmpeg/bin/lib'],
        LIBS=LIBS_COMMON)

    os.system(f'cp ffmpeg/bin/lib/*.so* {LOCATION}/{platform}')

elif 'windows' in platform:
    os.makedirs(f'{LOCATION}/{platform}', exist_ok=True)

    if os_platform.system().lower() == 'windows':
        env.Append(LIBS=[
            'avcodec.lib',
            'avformat.lib',
            'avdevice.lib',
            'avutil.lib',
            'swresample.lib',
            'swscale.lib'])
    else:
        env.Append(LIBS=LIBS_COMMON)

    env.Append(
        CPPPATH=['ffmpeg/bin/include'],
        LIBPATH=['ffmpeg/bin/bin'])
    os.system(f'cp ffmpeg/bin/bin/*.dll {LOCATION}/{platform}')

elif 'macos' in platform:
    os.makedirs(f'{LOCATION}/{platform}/Content/Frameworks', exist_ok=True)

    env.Append(
        CPPPATH=['ffmpeg/bin/include'],
        LIBPATH=[
            'ffmpeg/bin/lib',
            '/usr/local/lib'],  # Default macOS library path
        LIBS=LIBS_COMMON,
        LINKFLAGS=[  # macOS-specific linking flags
            '-stdlib=libc++',
            '-framework', 'CoreFoundation',
            '-framework', 'CoreVideo',
            '-framework', 'CoreMedia',
            '-framework', 'AVFoundation']
    )

    os.system(f'cp ffmpeg/bin/lib/*.dylib {LOCATION}/{platform}/Content/Frameworks')
elif 'web' in platform:
    print('Exporting for web isn\'t supported yet!')
elif 'android' in platform:
    print('Exporting for Android isn\'t supported yet!')
else:
    print('Invalid platform!')


# Godot compiling stuff
src = Glob('src/*.cpp')
libpath = f'{LOCATION}/{platform}/libgozen{env['suffix']}{env['SHLIBSUFFIX']}'

sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
