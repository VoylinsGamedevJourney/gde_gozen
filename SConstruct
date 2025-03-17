#!/usr/bin/env python
import os
import platform as os_platform


LIBS_COMMON = [
    'avcodec',
    'avformat',
    'avdevice',
    'avutil',
    'swresample',
    'swscale']
LOCATION = "test_room/addons/gde_gozen/bin"

march_flags = {
    'x86_64': 'x86-64',
    'arm64': 'native'  # Using 'native' for ARM64 is often safer than specifying specific architecture
}

env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])
env_suffix = env['suffix']
env_shlibsuffix = env['SHLIBSUFFIX']

jobs = ARGUMENTS.get('jobs', 4)
platform = ARGUMENTS.get('platform', 'linux')
arch = ARGUMENTS.get('arch', 'x86_64')
target = ARGUMENTS.get('target', 'template_debug').split('_')[-1]
libpath = f'{LOCATION}/{platform}_{arch}/libgozen{env_suffix}{env_shlibsuffix}'


if 'linux' in platform:
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
    env.Append(CCFLAGS=[f'-march={march_flags[arch]}'])

elif 'windows' in platform:
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

elif 'macos' in platform:
    # MacOS can only be build on a MacOS machine!
    macos_path = f'{LOCATION}/{platform}/{target}/lib'

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

    # os.system(f'cp ffmpeg/bin/lib/*.dylib {LOCATION}/{platform}/Content/Frameworks')
    libpath = f'{LOCATION}/{platform}_{arch}/{target}/libgozen{env_suffix}{env_shlibsuffix}'
elif 'android' in platform:
    print('Exporting for Android isn\'t supported yet!')


# Godot compiling stuff
src = Glob('src/*.cpp')
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
