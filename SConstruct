#!/usr/bin/env python
import os
import platform as os_platform
import time

libname = 'gozen'
folder_bin = './bin'  # Where to compile to

num_jobs = ARGUMENTS.get('jobs', 4)
platform = ARGUMENTS.get('platform', 'linux')
arch = ARGUMENTS.get('arch', 'x86_64')
target = ARGUMENTS.get('target', 'template_debug')

env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])

ffmpeg_build_args = '--enable-shared'
ffmpeg_build_args += ' --disable-postproc'
ffmpeg_build_args += ' --disable-avfilter'
ffmpeg_build_args += ' --quiet'
ffmpeg_build_args += f' --arch={arch}'
if ARGUMENTS.get('enable_small', 'yes') == 'yes':
    ffmpeg_build_args += ' --enable-small'
ffmpeg_build_args += ' --enable-gpl'


if 'linux' in platform:
    if ARGUMENTS.get('use_system', 'yes') == 'yes':  # For people who don't need the FFmpeg libs
        print("Normal linux build")

        env.Append(LINKFLAGS=['-static-libstdc++'])
        env.Append(CPPPATH=['/usr/include/ffmpeg/'])
        env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample'])

        os.makedirs(f'{folder_bin}/{platform}/{target}', exist_ok=True)
    else:  # For people needing FFmpeg binaries
        print("Full linux build")
        platform += '_full'

        env.Append(LINKFLAGS=['-static-libstdc++'])
        env.Append(CPPFLAGS=['-Iffmpeg/bin', '-Iffmpeg/bin/include'])
        env.Append(LIBPATH=[
            'ffmpeg/bin/include/libavcodec',
            'ffmpeg/bin/include/libavformat',
            'ffmpeg/bin/include/libavdevice',
            'ffmpeg/bin/include/libavutil',
            'ffmpeg/bin/include/libswresample',
            'ffmpeg/bin/lib'])

        if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
            os.chdir('ffmpeg')
            os.system('make distclean')
            time.sleep(5)

            ffmpeg_build_args += ' --extra-cflags="-fPIC" --extra-ldflags="-fpic"'
            os.system(f'./configure --prefix={folder_bin} {ffmpeg_build_args} --target-os=linux')
            time.sleep(5)

            os.system(f'make -j {num_jobs}')
            os.system(f'make -j {num_jobs} install')
            os.chdir('..')
        env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample'])

        os.makedirs(f'{folder_bin}/{platform}/{target}', exist_ok=True)
        os.system(f'cp ffmpeg/bin/lib/libav*.so* {folder_bin}/{platform}/{target}')
        os.system(f'cp ffmpeg/bin/lib/libswresample*.so* {folder_bin}/{platform}/{target}')
elif 'windows' in platform:
    # Building FFmpeg
    if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
        extra_args = ''
        if os_platform.system().lower() == 'linux':
            extra_args = '--cross-prefix=x86_64-w64-mingw32- --target-os=mingw32 --enable-cross-compile'

            # TEST: Testing if adding this makes it so copying files is no longer needed
            extra_args += ' --extra-ldflags="-static"'
            # Copying necessary files
            # os.makedirs(f'{folder_bin}/{platform}/{target}', exist_ok=True)
            # os.system(f'cp /usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll {folder_bin}/{platform}/{target}/')
            # os.system(f'cp /usr/x86_64-w64-mingw32/bin/libstdc++-6.dll {folder_bin}/{platform}/{target}/')
        else:
            extra_args = ' --target-os=windows'

        os.chdir('ffmpeg')
        os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']

        os.system('make distclean')
        time.sleep(5)
        os.system(f'./configure --prefix={folder_bin} {ffmpeg_build_args} {extra_args}')
        time.sleep(5)
        os.system(f'make -j {num_jobs}')
        os.system(f'make -j {num_jobs} install')
        os.chdir('..')

    if os_platform.system().lower() == 'windows':
        env.Append(LIBS=[
            'avcodec.lib',
            'avformat.lib',
            'avdevice.lib',
            'avutil.lib',
            'swresample.lib'])
    else:
        env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swresample'])

    env.Append(CPPPATH=['ffmpeg/bin/include'])
    env.Append(LIBPATH=['ffmpeg/bin/bin'])

    os.makedirs(f'{folder_bin}/{platform}/{target}', exist_ok=True)
    os.system(f'cp ffmpeg/bin/bin/av*.dll {folder_bin}/{platform}/{target}')
    os.system(f'cp ffmpeg/bin/bin/swresample*.dll {folder_bin}/{platform}/{target}')


src = Glob('src/*.cpp')
libpath = '{}/{}/{}/lib{}{}{}'.format(folder_bin, platform, target, libname, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)

