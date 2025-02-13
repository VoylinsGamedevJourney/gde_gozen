#!/usr/bin/env python
import os
import platform as os_platform
import macos_rpath_fix


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
target = ARGUMENTS.get('target', 'template_debug').split('_')[-1]
libpath = f'{LOCATION}/{platform}/{target}/libgozen{env['suffix']}{env['SHLIBSUFFIX']}'


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
    # MacOS can only be build on a MacOS machine!
    macos_path = f'{LOCATION}/{platform}/{target}/lib'
    os.makedirs(macos_path, exist_ok=True)

    env.Append(
        CPPPATH=['ffmpeg/bin/include'],
        LIBPATH=[
            'ffmpeg/bin/lib',
            'ffmpeg/bin/include/libavcodec',
            'ffmpeg/bin/include/libavformat',
            'ffmpeg/bin/include/libavdevice',
            'ffmpeg/bin/include/libavutil',
            'ffmpeg/bin/include/libswresample',
            'ffmpeg/bin/include/libswscale',
            macos_path,
            '/usr/local/lib'],
        LIBS=LIBS_COMMON,
        LINKFLAGS=[  # macOS-specific linking flags
            '-stdlib=libc++',
            '-framework', 'CoreFoundation',
            '-framework', 'CoreVideo',
            '-framework', 'CoreMedia',
            '-framework', 'AVFoundation',
            '-rpath', 'libPath']
    )

    os.system(f'cp ffmpeg/bin/lib/*.dylib {LOCATION}/{platform}/Content/Frameworks')
    libpath = f'{LOCATION}/{platform}/libgozen{env['suffix']}{env['SHLIBSUFFIX']}'
    macos_rpath_fix.main()
elif 'android' in platform:
    print('Exporting for Android isn\'t supported yet!')


# Godot compiling stuff
src = Glob('src/*.cpp')
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
