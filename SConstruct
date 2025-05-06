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

libpath = f'{LOCATION}/{platform}'
if platform != 'web':
    libpath += f'_{arch}'
libpath += '/libgozen{env_suffix}{env_shlibsuffix}'


if 'linux' in platform:
    env.Append(
        LINKFLAGS=['-static-libstdc++'],
        CCFLAGS=[f'-march={march_flags[arch]}'],
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
    macos_base_path = f'{LOCATION}/{platform}_{arch}/{target}'
    macos_lib_path = f'{macos_base_path}/lib'

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
            macos_lib_path,
            '/usr/local/lib'],
        LIBS=LIBS_COMMON,
        LINKFLAGS=[  # macOS-specific linking flags
            '-stdlib=libc++',
            '-framework', 'CoreFoundation',
            '-framework', 'CoreVideo',
            '-framework', 'CoreMedia',
            '-framework', 'AVFoundation',
            '-rpath', '@loader_path/lib']
    )

    libpath = f'{macos_base_path}/libgozen{env_suffix}{env_shlibsuffix}'

elif 'android' in platform:
    if arch == 'arm64':
        env.Append(CCFLAGS=['-march=armv8-a'])
    elif arch == 'armv7a':
        env.Append(CCFLAGS=['-march=armv7-a', '-mfloat-abi=softfp', '-mfpu=neon'])

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
elif 'web' in platform:
    web_bin_path = os.path.join(LOCATION, platform)
    web_include_path = os.path.join(web_bin_path, 'include')

    env.Append(
        CPPPATH=[web_include_path],
        LIBPATH=[web_bin_path],
        LIBS=[
            'libavcodec',
            'libavformat',
            'libavutil',
            'libswresample',
            'libswscale',
        ],
        CCFLAGS=[],
        LINKFLAGS=[]
    )

    env.AppendUnique(
        CCFLAGS=['-sUSE_PTHREADS=1'],
        LINKFLAGS=['-sUSE_PTHREADS=1', '-sSHARED_MEMORY=1']
    )

    initial_memory_mb = 1024
    stack_size_mb = 512

    print(f"Setting Emscripten Memory: Initial={initial_memory_mb}MB, Stack={stack_size_mb}MB")
    env.AppendUnique(LINKFLAGS=[
        f'-sINITIAL_MEMORY={initial_memory_mb}MB',
        '-sALLOW_MEMORY_GROWTH=1',
        f'-sSTACK_SIZE={stack_size_mb}MB',
        '-sSIDE_MODULE=1'
    ])

    libpath = os.path.join(web_bin_path, f'libgozen{env_suffix}.wasm')
else:
    print(f"Warning: Unsupported platform '{platform}' in SConstruct.")


# Godot compiling stuff
src = Glob('src/*.cpp')
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
