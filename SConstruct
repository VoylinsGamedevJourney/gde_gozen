#!/usr/bin/env python
import os
import platform as os_platform

libname = 'gozen'
folder_bin = './bin'  # Where to compile to

num_jobs = ARGUMENTS.get('jobs', 4)
platform = ARGUMENTS.get('platform', 'linux')
arch = ARGUMENTS.get('arch', 'x86_64')

env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])
env.Append(LIBS=['avcodec', 'avformat', 'avfilter', 'avdevice', 'avutil', 'swscale', 'swresample'])


if platform == 'linux':
    if ARGUMENTS.get('use_system', 'no') == 'no':  # For people who don't need the FFmpeg libs
        env.Append(CPPPATH=['/usr/include/ffmpeg/'])
    else:  # For people needing FFmpeg binaries
        platform += '_full'
        env.Append(CPPFLAGS=['-Iffmpeg', '-Iffmpeg/bin'])
        env.Append(CPPPATH=[
            'ffmpeg/bin/include/libavcodec',
            'ffmpeg/bin/include/libavformat',
            'ffmpeg/bin/include/libavfilter',
            'ffmpeg/bin/include/libavdevice',
            'ffmpeg/bin/include/libavutil',
            'ffmpeg/bin/include/libswscale',
            'ffmpeg/bin/include/libswresample'])
        env.Append(LIBPATH=['ffmpeg/lib'])

        os.chdir('ffmpeg')
        os.system(f'./configure --prefix={folder_bin} --arch={arch} --enable-shared --target-os=linux --disable-postproc')
        os.system('make distclean')
        os.system(f'./configure --prefix={folder_bin} --arch={arch} --enable-shared --target-os=linux --disable-postproc')
        os.system(f'make -j {num_jobs}')
        os.system(f'make -j {num_jobs} install')
        os.chdir('..')

        os.system(f'cp ffmpeg/bin/lib/*.so* {folder_bin}/{platform}/')
elif platform == 'windows':
    # Building FFmpeg
    extra_args = ''
    if os_platform.system().lower() == 'linux':
        os.environ['PATH'] = '/opt/bin/' + os.environ['PATH']
        extra_args = '--cross-prefix=x86_64-w64-mingw32- --target-os=mingw32'
        # Copying necessary files
        os.system(f'cp /usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll {folder_bin}/{platform}/')
        os.system(f'cp /usr/x86_64-w64-mingw32/bin/libstdc++-6.dll {folder_bin}/{platform}/')

    os.chdir('ffmpeg')
    os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']
    cross_prefix = 'x86_64-w64-mingw32-'
    extra_args = f'--cross_prefix={cross_prefix} --arch={arch} --target-os=mingw32'
    os.system('make distclean')
    os.system(f'./configure --prefix={folder_bin} --enable-shared {extra_args}')
    os.system(f'make -j {num_jobs}')
    os.system(f'make -j {num_jobs} install')
    os.chdir('..')

    if os_platform.system().lower() == 'windows':
        env.Append(LIBS=[
            'avcodec.lib', 'avformat.lib', 'avfilter.lib', 'avdevice.lib', 'avutil.lib', 'swscale.lib', 'swresample.lib'])
    env.Append(CPPPATH=['ffmpeg/include'])
    env.Append(LIBPATH=['ffmpeg/bin'])
    os.system(f'cp ffmpeg/bin/*.dll {folder_bin}/{platform}/')


src = Glob('src/*.cpp')
libpath = '{}/{}/lib{}{}{}'.format(folder_bin, platform, libname, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
