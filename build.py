#!/usr/bin/env python
"""
GDE GoZen Builder Script

This script handles the compilation of FFmpeg and the GDE GoZen plugin
for multiple platforms and architectures.

Windows and Linux can be build on Linux or Windows with WSL.
For MacOS you need to use MacOS itself else building fails.
"""

import os
import sys
import platform as os_platform
import subprocess
import glob
import shutil


THREADS: int = os.cpu_count() or 4
PATH_BUILD_WINDOWS: str = 'build_on_windows.py'

ARCH_X86_64: str = 'x86_64'
ARCH_ARM64: str = 'arm64'  # armv8
ARCH_ARMV7A: str = 'armv7a'
ARCH_WASM32: str = 'wasm32'

OS_LINUX: str = 'linux'
OS_WINDOWS: str = 'windows'
OS_MACOS: str = 'macos'
OS_ANDROID: str = 'android'

TARGET_DEV: str = 'debug'
TARGET_RELEASE: str = 'release'

# WARNING: Change the path to you android sdk!
ANDROID_SDK_PATH: str = '/opt/android-sdk'
ANDROID_API_LEVEL: int = 24

ENABLED_MODULES = [
    '--enable-swscale',

    '--enable-demuxer=ogg',
    '--enable-demuxer=matroska,webm',
]

ENABLE_AV1 = [
    '--enable-libaom',
    '--enable-decoder=av1',
    '--enable-parser=av1',
]

DISABLED_MODULES = [
    '--disable-muxers',
    '--disable-encoders',
    '--disable-postproc',
    '--disable-avdevice',
    '--disable-avfilter',
    '--disable-sndio',
    '--disable-doc',
    '--disable-programs',
    '--disable-ffprobe',
    '--disable-htmlpages',
    '--disable-manpages',
    '--disable-podpages',
    '--disable-txtpages',
    '--disable-ffplay',
    '--disable-ffmpeg',
    '--disable-hwaccels',
]


def _print_options(title: str, options: list[str]) -> int:
    # Helper function to print options and get the input.
    i: int = 1
    print(f'{title}:')

    for option in options:
        if i == 1:
            print(f'{i}. {option}; (default)')
        else:
            print(f'{i}. {option};')
        i += 1

    user_input: str = input('> ')

    if user_input.strip() == '':
        return 1

    try:
        return int(user_input)
    except ValueError:
        print('Invalid input. Using default option (1).')
        return 1


def get_ndk_host_tag() -> str:
    match os_platform.system().lower():
        case 'linux': return 'linux-x86_64'
        case 'darwin': return 'darwin-x86_64'
        case 'windows': return 'windows-x86_64'
        case _:
            print(f'Invalid host system: {os_platform.system()}')
            sys.exit(2)


def compile_ffmpeg(platform: str, arch: str) -> None:
    if os.path.exists('./ffmpeg/ffbuild/config.mak'):
        print('Cleaning FFmpeg...')
        subprocess.run(['make', 'distclean'], cwd='./ffmpeg/')
        subprocess.run(['rm', '-rf', 'bin'], cwd='./ffmpeg/')

    if platform == OS_LINUX:
        compile_ffmpeg_linux(arch)
    elif platform == OS_WINDOWS:
        compile_ffmpeg_windows(arch)
    elif platform == OS_MACOS:
        compile_ffmpeg_macos(arch)
    elif platform == OS_ANDROID:
        compile_ffmpeg_android(arch)


def compile_ffmpeg_linux(arch: str) -> None:
    print('Configuring FFmpeg for Linux ...')
    path: str = f'./test_room/addons/gde_gozen/bin/linux_{arch}'
    os.environ['PKG_CONFIG_PATH'] = '/usr/lib/pkgconfig'

    os.makedirs(path, exist_ok=True)

    cmd = [
        './configure',
        '--prefix=./bin',
        '--enable-shared',
        f'--arch={arch}',
        '--target-os=linux',
        '--quiet',
        '--enable-pic',
        '--enable-pthreads',
        '--extra-cflags=-fPIC',
        '--extra-ldflags=-fPIC',
    ]
    cmd += ENABLED_MODULES
    cmd += ENABLE_AV1
    cmd += DISABLED_MODULES

    if arch == 'arm64':
        cmd += [
            '--enable-cross-compile',
            '--cross-prefix=aarch64-linux-gnu-',
            '--cc=aarch64-linux-gnu-gcc',
        ]

    if subprocess.run(cmd, cwd='./ffmpeg/').returncode != 0:
        print('Error: FFmpeg failed!')

    print('Compiling FFmpeg for Linux ...')
    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    copy_linux_dependencies(path, arch)


def copy_linux_dependencies(path: str, arch: str):
    print('Copying lib files ...')
    for file in glob.glob('ffmpeg/bin/lib/*.so.*'):
        if file.count('.') == 2:
            shutil.copy2(file, path)

    print('Finding and copying required system .so dependencies ...', flush=True)

    def copy_dependencies(binary_path: str):
        try:
            output = subprocess.check_output(['ldd', binary_path], text=True)
            for line in output.splitlines():
                if '=>' not in line:
                    continue
                parts = line.strip().split('=>')
                if len(parts) < 2:
                    continue
                lib_path = parts[1].split('(')[0].strip()
                if not os.path.isfile(lib_path):
                    continue

                print(lib_path)

                if any(lib_path.endswith(name) for name in (
                    'libc.so.6',
                    'libm.so.6',
                    'libpthread.so.0',
                    'libdl.so.2',
                    'librt.so.1',
                    'ld-linux-x86-64.so.2',
                )):
                    continue

                lib_name = os.path.basename(lib_path)
                dest_path = os.path.join(path, lib_name)

                if os.path.abspath(lib_path) == os.path.abspath(dest_path):
                    continue  # Avoid SameFileError

                shutil.copy2(lib_path, path)
        except subprocess.CalledProcessError as e:
            print(f'Failed to run ldd on {binary_path}: {e}')

    # TODO: Make this work without manually adding version number
    binaries = [
        f'{path}/libavcodec.so.60',
        f'{path}/libavformat.so.60',
        f'{path}/libavutil.so.58',
        f'{path}/libswscale.so.7',
        f'{path}/libswresample.so.4',
        f'{path}/libgozen.linux.template_debug.{arch}.so'
    ]

    # TODO: Make this not copy all libraries, only needed ones (x264, x265)
    for binary in binaries:
        if os.path.exists(binary):
            copy_dependencies(binary)
        else:
            print(f'Warning: {binary} not found, skipping...')

    print('Compiling FFmpeg for Linux finished!')


def compile_ffmpeg_windows(arch: str) -> None:
    print('Configuring FFmpeg for Windows ...')
    path: str = f'./test_room/addons/gde_gozen/bin/windows_{arch}'
    os.environ['PKG_CONFIG_LIBDIR'] = f'/usr/{arch}-w64-mingw32/lib/pkgconfig'
    os.environ['PKG_CONFIG_PATH'] = f'/usr/{arch}-w64-mingw32/lib/pkgconfig'

    os.makedirs(path, exist_ok=True)

    cmd = [
        './configure',
        '--prefix=./bin',
        '--enable-shared',
        f'--arch={arch}',
        '--target-os=mingw32',
        '--enable-cross-compile',
        f'--cross-prefix={arch}-w64-mingw32-',
        '--quiet',
        '--extra-libs=-lpthread',
        '--extra-ldflags=-fpic',
        '--extra-cflags=-fPIC',
    ]
    cmd += ENABLED_MODULES
    cmd += ENABLE_AV1
    cmd += DISABLED_MODULES

    result = subprocess.run(cmd, cwd='./ffmpeg/')
    if result.returncode != 0:
        print('Error: FFmpeg failed!')

    print('Compiling FFmpeg for Windows ...')
    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for file in glob.glob('ffmpeg/bin/bin/*.dll'):
        shutil.copy2(file, path)

    # Somehow some distro's put the dll's in bin, and others in lib.
    if os.path.exists('/usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll'):
        subprocess.run(['cp', '/usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll', path], check=True)
    else:
        subprocess.run(['cp', '/usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll', path], check=True)

    subprocess.run(['cp', '/usr/x86_64-w64-mingw32/bin/libaom.dll', path], check=True)

    print('Compiling FFmpeg for Windows finished!')


def compile_ffmpeg_macos(arch: str) -> None:
    print('Configuring FFmpeg for MacOS ...')
    path_debug: str = './test_room/addons/gde_gozen/bin/macos/debug/lib'
    path_release: str = './test_room/addons/gde_gozen/bin/macos/release/lib'

    os.makedirs(path_debug, exist_ok=True)
    os.makedirs(path_release, exist_ok=True)

    cmd = [
        './configure',
        '--prefix=./bin',
        '--enable-shared',
        f'--arch={arch}',
        '--quiet',
        '--extra-ldflags=-mmacosx-version-min=10.13',
        '--extra-cflags=-fPIC -mmacosx-version-min=10.13',
    ]
    cmd += ENABLED_MODULES
    cmd += ENABLE_AV1
    cmd += DISABLED_MODULES

    result = subprocess.run(cmd, cwd='./ffmpeg/')
    if result.returncode != 0:
        print('Error: FFmpeg failed!')

    print('Compiling FFmpeg for MacOS ...')
    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for file in glob.glob('./ffmpeg/bin/lib/*.dylib'):
        shutil.copy2(file, path_debug)
        shutil.copy2(file, path_release)

    print('Compiling FFmpeg for MacOS finished!')


def compile_ffmpeg_android(arch: str) -> None:
    print('Configuring FFmpeg for Android ...')
    path: str = './test_room/addons/gde_gozen/bin/android_'
    ndk: str = os.getenv('ANDROID_NDK_ROOT')

    if not ndk:
        ndk = os.getenv('ANDROID_NDK')
    if not ndk or not os.path.isdir(ndk):
        print('ANDROID_NDK(_ROOT) environment variable is not set or invalid!')
        sys.exit(1)

    os.makedirs(path, exist_ok=True)

    # Getting correct settings.
    host_tag: str = get_ndk_host_tag()
    target_arch: str = ''
    arch_flags: str = ''
    ffmpeg_arch: str = ''
    strip_tool: str = ''

    if arch == ARCH_ARM64:
        path += 'arm64'
        target_arch = 'aarch64-linux-android'
        arch_flags = '-march=armv8-a'
        ffmpeg_arch = 'aarch64'
    else:  # armv7a
        path += 'arm32'
        target_arch = 'armv7a-linux-androideabi'
        arch_flags = '-march=armv7-a -mfloat-abi=softfp -mfpu=neon'
        ffmpeg_arch = 'arm'

    main_folder: str = f'{ndk}/toolchains/llvm/prebuilt/{host_tag}'
    toolchain_bin: str = f'{main_folder}/bin'
    toolchain_sysroot: str = f'{main_folder}/sysroot'
    cc: str = f'{toolchain_bin}/{target_arch}{ANDROID_API_LEVEL}-clang'
    cxx: str = f'{toolchain_bin}/{target_arch}{ANDROID_API_LEVEL}-clangxx'
    strip_tool: str = f'{toolchain_bin}/llvm-strip'

    cmd = [
        './configure',
        '--prefix=./bin',
        '--enable-shared',
        f'--arch={ffmpeg_arch}',
        '--target-os=android',
        '--enable-pic',
        '--enable-cross-compile',
        f'--cc={cc}',
        f'--cxx={cxx}',
        f'--sysroot={toolchain_sysroot}',
        f'--strip={strip_tool}',
        '--extra-cflags=-fPIC',
        f'--extra-ldflags={arch_flags}',
    ]
    cmd += ENABLED_MODULES
    # TODO: Implement a way to add AV1 support for Android
    # cmd += ENABLE_AV1
    cmd += DISABLED_MODULES

    if arch == ARCH_ARMV7A:
        cmd += ['--disable-vulkan']

    result = subprocess.run(cmd, cwd='./ffmpeg/')
    if result.returncode != 0:
        print('Error: FFmpeg failed!')

    print('Compiling FFmpeg for Android ...')
    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for file in glob.glob('ffmpeg/bin/lib/*.so*'):
        shutil.copy2(file, path)

    print('Compiling FFmpeg for Android finished!')


def macos_fix(arch) -> None:
    # This is a fix for the MacOS builds to get the libraries to properly connect to
    # the gdextension library. Without it, the FFmpeg libraries can't be found.
    print('Running fix for MacOS builds ...')

    debug_binary: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/debug/libgozen.macos.template_debug.{arch}.dylib'
    release_binary: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/release/libgozen.macos.template_release.{arch}.dylib'
    debug_bin_folder: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/debug/lib'
    release_bin_folder: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/release/lib'

    print('Updating @loader_path for MacOS builds')

    if os.path.exists(debug_binary):
        for file in os.listdir(debug_bin_folder):
            subprocess.run(['install_name_tool', '-change', f'./bin/lib/{file}', f'@loader_path/lib/{file}', debug_binary], check=True)
        subprocess.run(['otool', '-L', debug_binary], cwd='./')

    if os.path.exists(release_binary):
        for file in os.listdir(release_bin_folder):
            subprocess.run(['install_name_tool', '-change', f'./bin/lib/{file}', f'@loader_path/lib/{file}', release_binary], check=True)
        subprocess.run(['otool', '-L', release_binary], cwd='./')


def main():
    print('v===================v')
    print('| GDE GoZen builder |')
    print('^===================^')

    if sys.version_info < (3, 10):
        print('Python 3.10+ is required to run this script!')
        sys.exit(2)

    if os_platform.system() == 'Windows':
        # Oh no, Windows detected. ^^"
        subprocess.run([sys.executable, PATH_BUILD_WINDOWS], cwd='./', check=True)
        sys.exit(3)

    if os.path.exists('./ffmpeg/.config'):
        match _print_options('Init/Update submodules', ['no', 'initialize', 'update']):
            case 2:
                subprocess.run(['git', 'submodule', 'update',
                                '--init', '--recursive'], cwd='./')
            case 3:
                subprocess.run(['git', 'submodule', 'update',
                                '--recursive', '--remote'], cwd='./')
    else:
        subprocess.run(['git', 'submodule', 'update', '--init', '--recursive'], cwd='./')

    # Arm64 isn't supported yet by mingw for Windows, so x86_64 only.
    title_arch: str = 'Choose architecture'
    platform: str = OS_LINUX
    arch: str = ARCH_X86_64
    match _print_options('Select platform', [OS_LINUX, OS_WINDOWS, OS_MACOS, OS_ANDROID]):
        case 2:
            platform = OS_WINDOWS
        case 3:
            platform = OS_MACOS
            arch = ARCH_ARM64
        case 4:
            platform = OS_ANDROID
            if _print_options(title_arch, [ARCH_ARM64, ARCH_ARMV7A]) == 2:
                arch = ARCH_ARMV7A
            else:
                arch = ARCH_ARM64
        case _:  # Linux
            if _print_options(title_arch, [ARCH_X86_64, ARCH_ARM64]) == 2:
                arch = ARCH_ARM64

    target: str = TARGET_DEV
    if _print_options('Select target', [TARGET_DEV, TARGET_RELEASE]) == 2:
        target = TARGET_RELEASE

    clean_scons = True
    if _print_options('Clean Scons?', ['yes', 'no']) == 2:
        clean_scons = False

    if _print_options('(Re)compile ffmpeg?', ['yes', 'no']) == 1:
        compile_ffmpeg(platform, arch)

    # Godot requires arm32 instead of armv7a.
    if arch == ARCH_ARMV7A:
        arch = "arm32"

    cmd = ['scons', f'-j{THREADS}', f'target=template_{target}', f'platform={platform}', f'arch={arch}']
    env = os.environ.copy()

    if platform == OS_ANDROID:
        # We need to check if ANDROID_HOME is set to the sdk folder.
        if os.getenv('ANDROID_HOME') is None:
            if os_platform.system() == 'Linux':
                print('Linux detected for setting ANDROID_HOME')
                env['ANDROID_HOME'] = os.getenv('ANDROID_HOME', ANDROID_SDK_PATH)

    if clean_scons:
        clean_cmd = ['scons', '--clean', f'-j{THREADS}', f'target=template_{target}', f'platform={platform}', f'arch={arch}']
        subprocess.run(clean_cmd, cwd='./', env=env)

    subprocess.run(cmd, cwd='./', env=env)

    if platform == OS_MACOS:
        macos_fix(arch)

    print('')
    print('v=========================v')
    print('| Done building GDE GoZen |')
    print('^=========================^')
    print('')


if __name__ == '__main__':
    main()
