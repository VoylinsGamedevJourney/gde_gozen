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


if platform == 'linux':
	# For people who don't need the FFmpeg libs
	env.Append(CPPPATH=['/usr/include/ffmpeg/'])

	# For people needing FFmpeg binaries
# os.chdir('ffmpeg')
# os.system(f'./configure --arch=x86_64 --enable-shared --target-os=linux --disable-postproc')# --extra-cflags="-fPIC" --extra-ldflags="-fpic"')
# os.system('make distclean')
# os.system(f'./configure --arch=x86_64 --enable-shared --target-os=linux --disable-postproc')# --extra-cflags="-fPIC" --extra-ldflags="-fpic"')
# os.system(f'make -j {num_jobs}')
# # os.system(f'make -j {num_jobs} install')
# os.chdir('..')
#
# env.Append(CPPFLAGS=['-Iffmpeg'])
# env.Append(CPPPATH=[
# 'ffmpeg/include/libavcodec',
# 'ffmpeg/include/libavformat',
# 'ffmpeg/include/libavfilter',
# 'ffmpeg/include/libavdevice',
# 'ffmpeg/include/libavutil',
# 'ffmpeg/include/libswscale',
# 'ffmpeg/include/libswresample'])
# env.Append(LIBPATH=['ffmpeg/lib'])
#
	# os.system('cp ffmpeg/libavcodec/*.so* bin/linux/')
	# os.system('cp ffmpeg/libavformat/*.so* bin/linux/')
	# os.system('cp ffmpeg/libavfilter/*.so* bin/linux/')
	# os.system('cp ffmpeg/libavdevice/*.so* bin/linux/')
	# os.system('cp ffmpeg/libavutil/*.so* bin/linux/')
	# os.system('cp ffmpeg/libswscale/*.so* bin/linux/')
	# os.system('cp ffmpeg/libswresample/*.so* bin/linux/')
elif platform == 'windows':
	# Building FFmpeg
	extra_args = ''
	if os_platform.system().lower() == 'linux':
		os.environ['PATH'] = '/opt/bin/' + os.environ['PATH']
		extra_args = '--cross-prefix=x86_64-w64-mingw32- --target-os=mingw32'

	os.chdir('ffmpeg')
	os.system(f'./configure --enable-shared {extra_args} --arch=x86_64')
	os.system('make distclean')
	os.system(f'./configure --enable-shared {extra_args} --arch=x86_64')
	os.system(f'make -j {num_jobs}')
	# os.system(f'make -j {num_jobs} install')
	os.chdir('..')

	if os_platform.system().lower() == 'windows':
		env.Append(LIBS=[
			'avcodec.lib', 'avformat.lib', 'avfilter.lib', 'avdevice.lib', 'avutil.lib',
			'swscale.lib', 'swresample.lib'])
	env.Append(CPPPATH=['ffmpeg/include'])
	env.Append(LIBPATH=['ffmpeg/bin'])
	os.system('cp ffmpeg/bin/*.dll bin/windows/')


src = Glob('src/*.cpp')
libpath = 'bin/{}/lib{}{}{}'.format(platform, libname, env['suffix'], env['SHLIBSUFFIX'])
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
