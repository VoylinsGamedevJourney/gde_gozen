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


ffmpeg_args = '--enable-shared'
ffmpeg_args += ' --disable-postproc'
ffmpeg_args += ' --disable-avfilter'
ffmpeg_args += ' --disable-programs --disable-ffmpeg --disable-ffplay --disable-ffprobe'
ffmpeg_args += ' --disable-doc --disable-htmlpages --disable-manpages --disable-podpages --disable-txtpages'
ffmpeg_args += ' --quiet'
ffmpeg_args += f' --arch={arch}'


os.makedirs(f'bin/{platform}/{target}', exist_ok=True)

if 'linux' in platform:
    if ARGUMENTS.get('use_system', 'yes') == 'yes':  # For people who don't need the FFmpeg libs
        env.Append(LINKFLAGS=['-static-libstdc++'])
        env.Append(CPPPATH=['/usr/include/ffmpeg/'])
        env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample'])

        os.makedirs(f'bin/{platform}/{target}', exist_ok=True)
    else:  # For people needing FFmpeg binaries
        platform += '_full'
        if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
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

        print(os.system(f'cp ffmpeg/bin/lib/*.so* bin/{platform}/{target}'))
        env.Append(LIBS=[
            'avcodec',
            'avformat',
            'avdevice',
            'avutil',
            'swresample',
            'swscale'])
elif 'windows' in platform:
    if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
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
    os.system(f'cp ffmpeg/bin/bin/*.dll bin/{platform}/{target}')


src = Glob('src/*.cpp')
libpath = 'bin/{}/{}/libgozen{}{}'.format(platform, target, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
