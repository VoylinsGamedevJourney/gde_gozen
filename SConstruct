#!/usr/bin/env python
import os
import platform as os_platform
import time


env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])


jobs = ARGUMENTS.get('jobs', 4)
arch = ARGUMENTS.get('arch', 'x86_64')
target = ARGUMENTS.get('target', 'template_debug').replace('template_', '')
platform = ARGUMENTS.get('platform', 'linux')
location = ARGUMENTS.get('location', 'bin')


ffmpeg_args = '--enable-shared --enable-gpl'
ffmpeg_args += ' --disable-postproc'
ffmpeg_args += ' --disable-avfilter'
ffmpeg_args += ' --disable-programs --disable-ffmpeg --disable-ffplay --disable-ffprobe'
ffmpeg_args += ' --disable-doc --disable-htmlpages --disable-manpages --disable-podpages --disable-txtpages'
ffmpeg_args += ' --quiet'
ffmpeg_args += ' --disable-sndio'
ffmpeg_args += f' --arch={arch}'


if 'linux' in platform:
    if ARGUMENTS.get('use_system', 'yes') == 'yes':  # For people who don't need the FFmpeg libs
        os.makedirs(f'{location}/{platform}/{target}', exist_ok=True)

        env.Append(LINKFLAGS=['-static-libstdc++'])
        env.Append(CPPPATH=['/usr/include/ffmpeg/'])
        env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample'])
    else:  # For people needing FFmpeg binaries
        platform += '_full'
        os.makedirs(f'{location}/{platform}/{target}', exist_ok=True)
        if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
            print('Compiling FFmpeg for Linux')

            ffmpeg_args += ' --extra-cflags="-fPIC" --extra-ldflags="-fpic"'

            os.chdir('ffmpeg')
            os.system('make distclean')
            time.sleep(5)

            os.system(f'./configure --prefix=./bin {ffmpeg_args} --target-os=linux')
            time.sleep(5)

            os.system(f'make -j {jobs}')
            os.system(f'make -j {jobs} install')
            os.chdir('..')

        env.Append(LINKFLAGS=['-static-libstdc++'])
        env.Append(CPPFLAGS=['-Iffmpeg/bin', '-Iffmpeg/bin/include'])
        env.Append(LIBPATH=[
            'ffmpeg/bin/include/libavcodec',
            'ffmpeg/bin/include/libavformat',
            'ffmpeg/bin/include/libavdevice',
            'ffmpeg/bin/include/libavutil',
            'ffmpeg/bin/include/libswresample',
            'ffmpeg/bin/include/libswscale',
            'ffmpeg/bin/lib'])

        print(os.system(f'cp ffmpeg/bin/lib/*.so* {location}/{platform}/{target}'))
        env.Append(LIBS=[
            'avcodec',
            'avformat',
            'avdevice',
            'avutil',
            'swresample',
            'swscale'])
elif 'windows' in platform:
    os.makedirs(f'{location}/{platform}/{target}', exist_ok=True)

    if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
        print('Compiling FFmpeg for Windows')

        if os_platform.system().lower() == 'linux':
            ffmpeg_args += ' --cross-prefix=x86_64-w64-mingw32- --target-os=mingw32'
            ffmpeg_args += ' --enable-cross-compile'
            ffmpeg_args += ' --extra-ldflags="-static"'
            ffmpeg_args += ' --extra-cflags="-fPIC" --extra-ldflags="-fpic"'
        else:
            ffmpeg_args += ' --target-os=windows'

        os.chdir('ffmpeg')
        os.system('make distclean')
        time.sleep(5)

        os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']
        os.system(f'./configure --prefix=./bin {ffmpeg_args}')
        time.sleep(5)

        os.system(f'make -j {jobs}')
        os.system(f'make -j {jobs} install')
        os.chdir('..')

    if os_platform.system().lower() == 'windows':
        env.Append(LIBS=[
            'avcodec.lib',
            'avformat.lib',
            'avdevice.lib',
            'avutil.lib',
            'swresample.lib',
            'swscale.lib'])
    else:
        env.Append(LIBS=[
            'avcodec',
            'avformat',
            'avdevice',
            'avutil',
            'swresample',
            'swscale'])

    env.Append(CPPPATH=['ffmpeg/bin/include'])
    env.Append(LIBPATH=['ffmpeg/bin/bin'])
    os.system(f'cp ffmpeg/bin/bin/*.dll {location}/{platform}/{target}')
elif 'macos' in platform:
    # Cross compiling not possible, need a MacOS system
    os.makedirs(f'{location}/{platform}/{target}', exist_ok=True)

    if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
        print('Compiling FFmpeg for MacOS')

        ffmpeg_args += ' --target-os=darwin'
        ffmpeg_args += ' --extra-cflags="-fPIC -mmacosx-version-min=10.13"'
        ffmpeg_args += ' --extra-ldflags="-mmacosx-version-min=10.13"'

        os.chdir('ffmpeg')
        os.system('make distclean')
        time.sleep(5)

        os.system(f'./configure --prefix=./bin {ffmpeg_args}')
        time.sleep(5)

        os.system(f'make -j {jobs}')
        os.system(f'make -j {jobs} install')
        os.chdir('..')

    env.Append(CPPPATH=['ffmpeg/bin/include'])
    env.Append(LIBPATH=[
        'ffmpeg/bin/lib',
        '/usr/local/lib'  # Default macOS library path
    ])
    env.Append(LIBS=[
        'avcodec',
        'avformat',
        'avdevice',
        'avutil',
        'swresample',
        'swscale'
    ])

    # macOS-specific linking flags
    env.Append(LINKFLAGS=[
        '-stdlib=libc++',
        '-framework', 'CoreFoundation',
        '-framework', 'CoreVideo',
        '-framework', 'CoreMedia',
        '-framework', 'AVFoundation'
    ])

    os.system(f'cp ffmpeg/bin/lib/*.dylib {location}/{platform}/{target}')

CacheDir('.scons-cache')
Decider('MD5')

src = Glob('src/*.cpp')
libpath = '{}/{}/{}/libgozen{}{}'.format(location, platform, target, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
