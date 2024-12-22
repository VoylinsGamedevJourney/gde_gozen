#!/usr/bin/env python
import os
import platform as os_platform
import time
import macos_rpath_fix

LIBS_COMMON = [
    'avcodec',
    'avformat',
    'avdevice',
    'avutil',
    'swresample',
    'swscale']
SLEEP_TIME = 3


env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])

gpl = ARGUMENTS.get('enable_gpl', 'no')
jobs = ARGUMENTS.get('jobs', 4)
arch = ARGUMENTS.get('arch', 'x86_64')
target = ARGUMENTS.get('target', 'template_debug').replace('template_', '')
platform = ARGUMENTS.get('platform', 'linux')
location = ARGUMENTS.get('location', 'bin')
use_system = ARGUMENTS.get('use_system', 'yes')
recompile_ffmpeg = ARGUMENTS.get('recompile_ffmpeg', 'yes')


ffmpeg_args = '--enable-shared --quiet' +\
              ' --disable-postproc --disable-avfilter --disable-sndio' +\
              ' --disable-programs --disable-ffmpeg --disable-ffplay' +\
              ' --disable-ffprobe --disable-doc --disable-htmlpages' +\
              ' --disable-manpages --disable-podpages --disable-txtpages' +\
              f' --arch={arch}'

if gpl == 'yes':
    print('GPL3 enabled')
    ffmpeg_args += ' --enable-gpl --enable-version3 --enable-lto'

    # NOTE: These libraries are needed for rendering and other things, this
    # means that rendering right now is only possible on Linux systems.
    if 'linux' in platform:
        ffmpeg_args += ' --enable-libaom --enable-nvdec --enable-nvenc' +\
                       ' --enable-libopus --enable-libpulse --enable-opencl' +\
                       ' --enable-libtheora --enable-libvpx --enable-libvpl' +\
                       ' --enable-libass --enable-libdav1d --enable-libdrm' +\
                       ' --enable-libsoxr --enable-vulkan --enable-opengl' +\
                       ' --enable-libmp3lame --enable-libvorbis' +\
                       ' --enable-librav1e --enable-libsvtav1' +\
                       ' --enable-libx264 --enable-libx265' +\
                       ' --enable-libxml2 --enable-libxvid' +\
                       ' --enable-libopenmpt --enable-cuda-llvm'

# LINUX ############################################################### LINUX #
# For people who don't need the FFmpeg libs (FFmpeg 6+ already installed)
if 'linux' in platform and use_system == 'yes':
    os.makedirs(f'{location}/{platform}/{target}', exist_ok=True)
    env.Append(
        LINKFLAGS=['-static-libstdc++'],
        CPPPATH=['/usr/include/ffmpeg/'],
        LIBS=LIBS_COMMON)


# LINUX_FULL ##################################################### LINUX_FULL #
# For people needing FFmpeg binaries (Ubuntu, ... don't have FFmpeg 6+ yet)
elif 'linux' in platform:
    platform += '_full'
    os.makedirs(f'{location}/{platform}/{target}', exist_ok=True)

    if recompile_ffmpeg == 'yes':
        print('Compiling FFmpeg for Linux')
        ffmpeg_args += ' --extra-cflags="-fPIC" --extra-ldflags="-fpic"' +\
                       ' --target-os=linux'

        os.chdir('ffmpeg')
        os.system('make distclean')
        time.sleep(SLEEP_TIME)

        os.system(f'./configure --prefix=./bin {ffmpeg_args}')
        time.sleep(SLEEP_TIME)

        os.system(f'make -j {jobs}')
        os.system(f'make -j {jobs} install')
        os.chdir('..')

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

    os.system(f'cp ffmpeg/bin/lib/*.so* {location}/{platform}/{target}')


# WINDOWS ########################################################### WINDOWS #
# For people who for some reason use Windows
elif 'windows' in platform:
    os.makedirs(f'{location}/{platform}/{target}', exist_ok=True)

    if recompile_ffmpeg == 'yes':
        print('Compiling FFmpeg for Windows')

        if os_platform.system().lower() == 'linux':
            ffmpeg_args += ' --cross-prefix=x86_64-w64-mingw32-' +\
                           ' --target-os=mingw32 --enable-cross-compile' +\
                           ' --extra-ldflags="-static"' +\
                           ' --extra-cflags="-fPIC" --extra-ldflags="-fpic"'
        else:
            ffmpeg_args += ' --target-os=windows'

        os.chdir('ffmpeg')
        os.system('make distclean')
        time.sleep(SLEEP_TIME)

        os.environ['PATH'] = '/opt/bin:' + os.environ['PATH']
        os.system(f'./configure --prefix=./bin {ffmpeg_args}')
        time.sleep(SLEEP_TIME)

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
        env.Append(LIBS=LIBS_COMMON)

    env.Append(
        CPPPATH=['ffmpeg/bin/include'],
        LIBPATH=['ffmpeg/bin/bin'])
    os.system(f'cp ffmpeg/bin/bin/*.dll {location}/{platform}/{target}')


# MACOS ############################################################### MACOS #
# For the people who like shiny/working computers but don't like money and/or right to repair
# NOTE: Cross compiling not possible, need a MacOS system
elif 'macos' in platform:

    os.makedirs(f'{location}/{platform}/{target}/lib', exist_ok=True)

    if recompile_ffmpeg == 'yes':
        print('Compiling FFmpeg for MacOS')

        ffmpeg_args += ' --extra-cflags="-fPIC -mmacosx-version-min=10.13"' +\
                       ' --extra-ldflags="-mmacosx-version-min=10.13"'

        os.chdir('ffmpeg')
        os.system('make distclean')
        time.sleep(SLEEP_TIME)

        os.system(f'./configure --prefix=./bin {ffmpeg_args}')
        time.sleep(SLEEP_TIME)

        os.system(f'make -j {jobs}')
        os.system(f'make -j {jobs} install')
        os.chdir('..')

    libPath = f'{location}/{platform}/{target}/lib'

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
            libPath,
            '/usr/local/lib'],  # Default macOS library path
        LIBS=LIBS_COMMON,
        LINKFLAGS=[  # macOS-specific linking flags
            '-stdlib=libc++',
            '-framework', 'CoreFoundation',
            '-framework', 'CoreVideo',
            '-framework', 'CoreMedia',
            '-framework', 'AVFoundation',
            '-rpath', libPath]
    )
    # also ich muss es händisch in testtoom/bin/lib kopieren
    os.makedirs(libPath, exist_ok=True)
    os.system(f'cp ffmpeg/bin/lib/*.dylib {libPath}')

    macos_rpath_fix.main()


elif 'web' in platform:
    print('Exporting for web isn\'t supported yet!')
elif 'android' in platform:
    print('Exporting for Android isn\'t supported yet!')
else:
    print('Invalid platform!')


# Caching stuff
CacheDir('.scons-cache')
Decider('MD5')

# Godot compiling stuff
src = Glob('src/*.cpp')
libpath = '{}/{}/{}/libgozen{}{}'.format(
    location,
    platform,
    target,
    env['suffix'],
    env['SHLIBSUFFIX'])

sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
