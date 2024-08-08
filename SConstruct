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
env.Append(LIBS=['avcodec', 'avformat', 'avdevice', 'avutil', 'swscale', 'swresample'])

ffmpeg_build_args = '--enable-shared'
ffmpeg_build_args += ' --disable-programs'
ffmpeg_build_args += ' --disable-doc'
ffmpeg_build_args += ' --disable-postproc'
ffmpeg_build_args += ' --disable-avfilter'
ffmpeg_build_args += ' --quiet'
ffmpeg_build_args += ' --disable-logging'
ffmpeg_build_args += f' --arch={arch}'
if ARGUMENTS.get('enable_gpl', 'no') == 'yes':
    ffmpeg_build_args += ' --enable-gpl'
if ARGUMENTS.get('include_renderer', 'no') == 'yes':
    env.Append(CPPFLAGS=['-DEXPORT_RENDERER'])
else:
    platform += '_video_only'


if 'linux' in platform:
    if ARGUMENTS.get('use_system', 'yes') == 'yes':  # For people who don't need the FFmpeg libs
        print("Normal linux build")
        env.Append(CPPPATH=['/usr/include/ffmpeg/'])
    else:  # For people needing FFmpeg binaries
        print("Full linux build")
        platform += '_full'
        env.Append(CPPFLAGS=['-Iffmpeg/bin', '-Iffmpeg/bin/include'])
        env.Append(LIBPATH=[
            'ffmpeg/bin/include/libavcodec',
            'ffmpeg/bin/include/libavformat',
            'ffmpeg/bin/include/libavdevice',
            'ffmpeg/bin/include/libavutil',
            'ffmpeg/bin/include/libswscale',
            'ffmpeg/bin/include/libswresample'])
        env.Append(LIBPATH=['ffmpeg/bin/lib'])
        
        if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
            os.chdir('ffmpeg')
            os.system('make distclean')
            time.sleep(5)
            # These may be needed when running into trouble compiling
            # --extra-cflags="-fPIC" --extra-ldflags="-fpic" --target-os=linux') 
            os.system(f'./configure --prefix={folder_bin} {ffmpeg_build_args} --target-os=linux')
            time.sleep(5)

            os.system(f'make -j {num_jobs}')
            os.system(f'make -j {num_jobs} install')
            os.chdir('..')

        os.makedirs(f'{folder_bin}/{platform}/{target}', exist_ok=True)
        os.system(f'cp ffmpeg/bin/lib/*.so* {folder_bin}/{platform}/{target}')
elif 'windows' in platform:
    # Building FFmpeg
    if ARGUMENTS.get('recompile_ffmpeg', 'yes') == 'yes':
        extra_args = ''
        if os_platform.system().lower() == 'linux':
            extra_args = '--cross-prefix=x86_64-w64-mingw32- --target-os=mingw32 --enable-cross-compile'

            # TEST: Testing if adding this makes it so copying files is no longer needed
            extra_args += ' --extra-ldflags="-static"'
            # Copying necessary files
            # os.system(f'cp /usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll {folder_bin}/{platform}/')
            # os.system(f'cp /usr/x86_64-w64-mingw32/bin/libstdc++-6.dll {folder_bin}/{platform}/')
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
            'swscale.lib',
            'swresample.lib'])
    env.Append(CPPPATH=['ffmpeg/bin/include'])
    env.Append(LIBPATH=['ffmpeg/bin/bin'])

    os.makedirs(f'{folder_bin}/{platform}/{target}', exist_ok=True)
    os.system(f'cp ffmpeg/bin/bin/*.dll {folder_bin}/{platform}/{target}')


src = Glob('src/*.cpp')
libpath = '{}/{}/{}/lib{}{}{}'.format(folder_bin, platform, target, libname, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
