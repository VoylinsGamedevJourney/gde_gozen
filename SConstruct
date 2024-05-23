#!/usr/bin/env python
import os
import platform as os_platform


libname = 'gozen'
projectdir = 'test_room'

num_jobs = ARGUMENTS.get('jobs', 4)
platform = ARGUMENTS.get('platform', 'linux')

env = SConscript('godot_cpp/SConstruct')
env.Append(CPPPATH=['src'])
env.Append(LIBS=['avcodec', 'avformat', 'avfilter', 'avdevice', 'avutil', 'swscale', 'swresample'])


ffmpeg_bin = os.path.join(os.path.dirname(os.path.realpath('__file__')), 'ffmpeg_bin')
os.makedirs(ffmpeg_bin, exist_ok=True)


if platform == 'linux':
	env.Append(CPPPATH=['/usr/include/ffmpeg/'])

	# For people needing FFmpeg binaries
	env.Append(CPPFLAGS=['-Iffmpeg_bin'])
	env.Append(LIBPATH=[
		'ffmpeg_bin/libavcodec',
		'ffmpeg_bin/libavformat',
		'ffmpeg_bin/libavfilter',
		'ffmpeg_bin/libavdevice',
		'ffmpeg_bin/libswscale',
		'ffmpeg_bin/libavutil',
		'ffmpeg_bin/libswresample'])
	os.chdir('ffmpeg')
	os.system(f'./configure --prefix={ffmpeg_bin} --arch=x86_64 --enable-shared --extra-cflags="-fPIC" --extra-ldflags="-fpic"')
	os.system('make distclean')
	os.system(f'./configure --prefix={ffmpeg_bin} --arch=x86_64 --enable-shared --extra-cflags="-fPIC" --extra-ldflags="-fpic"')
	os.system(f'make -j {num_jobs}')
	# os.system(f'make -j {num_jobs} install')
	os.chdir('..')
	os.system(f'cp {ffmpeg_bin}/lib/*.so* bin/linux/')
elif platform == 'windows':
	# Building FFmpeg
	extra_args = ''
	if os_platform.system().lower() == 'linux':
		os.environ['PATH'] = '/opt/bin/' + os.environ['PATH']
		extra_args = f'--cross-prefix=x86_64-w64-mingw32- --target-os=mingw32'

	os.chdir('ffmpeg')
	os.system(f'./configure --prefix={ffmpeg_bin} --enable-shared {extra_args} --arch=x86_64')
	os.system('make distclean')
	os.system(f'./configure --prefix={ffmpeg_bin} --enable-shared {extra_args} --arch=x86_64')
	os.system(f'make -j {num_jobs}')
	# os.system(f'make -j {num_jobs} install')
	os.chdir('..')

	if os_platform.system().lower() == 'windows':
		env.Append(LIBS=[
			'avcodec.lib', 'avformat.lib', 'avfilter.lib', 'avdevice.lib', 'avutil.lib',
			'swscale.lib', 'swresample.lib'])
	env.Append(CPPPATH=['ffmpeg_bin/include'])
	env.Append(LIBPATH=['ffmpeg_bin/bin'])
	os.system(f'cp {ffmpeg_bin}/bin/*.dll bin/windows/')


src = Glob('src/*.cpp')
libpath = 'bin/{}/lib{}{}{}'.format(platform, libname, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
