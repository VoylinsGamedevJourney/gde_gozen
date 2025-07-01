#!/usr/bin/env python
import os
import platform as os_platform


LIBS_COMMON = [
    'avcodec',
    'avformat',
    'avutil',
    'swresample',
    'swscale']
LOCATION = "test_room/addons/gde_gozen/bin"

march_flags = {
    'x86_64': 'x86-64',
    'arm64': 'armv8-a'
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


if 'linux' in platform:
    libpath += f'_{arch}/libgozen{env_suffix}{env_shlibsuffix}'

    if arch == 'arm64':
        march_flags[arch] = 'armv8-a'
        env['CC'] = 'aarch64-linux-gnu-gcc'
        env['CXX'] = 'aarch64-linux-gnu-g++'
        env['LINK'] = 'aarch64-linux-gnu-g++'

    env.Append(
        LINKFLAGS=['-static-libstdc++'],
        CCFLAGS=[f'-march={march_flags[arch]}'],
        CPPFLAGS=[
            '-Iffmpeg/bin',
            '-Iffmpeg/bin/include'],
        LIBPATH=['ffmpeg/bin/lib'],
        LIBS=LIBS_COMMON)
elif 'windows' in platform:
    libpath += f'_{arch}/libgozen{env_suffix}{env_shlibsuffix}'
    if os_platform.system().lower() == 'windows':
        env.Append(LIBS=[
            'avcodec.lib',
            'avformat.lib',
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
    macos_base_path = f'{libpath}/{target}'
    macos_lib_path = f'{macos_base_path}/lib'
    libpath = f'{macos_base_path}/libgozen{env_suffix}{env_shlibsuffix}'
    os.makedirs(macos_lib_path, exist_ok=True)

    env.Append(
        CPPPATH=['ffmpeg/bin/include'],
        LIBPATH=[
            'ffmpeg/bin/lib',
            'ffmpeg/bin/include/libavcodec',
            'ffmpeg/bin/include/libavformat',
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
elif 'android' in platform:
    libpath += f'_{arch}/libgozen{env_suffix}{env_shlibsuffix}'

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
            'ffmpeg/bin/include/libavutil',
            'ffmpeg/bin/include/libswresample',
            'ffmpeg/bin/include/libswscale',
            'ffmpeg/bin/lib'],
        LIBS=LIBS_COMMON)
else:
    print(f"Warning: Unsupported platform '{platform}' in SConstruct.")


# Godot compiling stuff
src = Glob('src/*.cpp')
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
