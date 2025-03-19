import os
import sys
import platform as os_platform
import subprocess
import glob
import shutil


# Windows and Linux can be build on Linux or Windows with WSL.
# For MacOS you need to use MacOS itself else building fails.


threads = os.cpu_count() or 4

path_build_windows = 'build_on_windows.py'

title_submodules = 'Init/Update submodules'
title_platform = 'Select platform'
title_arch = 'Choose architecture'
title_recompile_ffmpeg = 'Do you want to (re)compile ffmpeg?'
title_target = 'Select target'

option_yes = 'yes'
option_no = 'no'
option_init = 'initialize'
option_update = 'update'
option_debug = 'debug'
option_release = 'release'

arch_x86_64 = 'x86_64'
arch_arm64 = 'arm64'

os_linux = 'linux'
os_windows = 'windows'
os_macos = 'macos'
os_android = 'android'

target_dev = 'debug'
target_release = 'release'


def _print_options(a_title, a_options):
    # Helper function to print options and get the input.
    i = 1
    print(f'{a_title}:')

    for l_option in a_options:
        if i == 1:
            print(f'{i}. {l_option}; (default)')
        else:
            print(f'{i}. {l_option};')
        i += 1

    return input('> ')


def compile_ffmpeg(a_platform, a_arch):
    match _print_options(title_recompile_ffmpeg, [option_yes, option_no]):
        case '2':
            return

    if os.path.exists('./ffmpeg/ffbuild/config.mak'):
        print('Cleaning FFmpeg...')
        subprocess.run(['make', 'distclean'], cwd='./ffmpeg/')
        subprocess.run(['rm', '-rf', 'bin'], cwd='./ffmpeg/')

    if a_platform == os_linux:
        compile_ffmpeg_linux(a_arch)
    elif a_platform == os_windows:
        compile_ffmpeg_windows(a_arch)
    elif a_platform == os_macos:
        compile_ffmpeg_macos(a_arch)
    elif a_platform == os_android:
        compile_ffmpeg_android(a_arch)


def compile_ffmpeg_linux(a_arch):
    print('Configuring FFmpeg for Linux ...')
    l_path = f'./test_room/addons/gde_gozen/bin/linux_{a_arch}'
    os.environ['PKG_CONFIG_PATH'] = '/usr/lib/pkgconfig'

    os.makedirs(l_path, exist_ok=True)

    subprocess.run([
        './configure', '--prefix=./bin', '--enable-shared', f'--arch={a_arch}',
        '--target-os=linux', '--quiet', '--enable-pic',
        '--extra-cflags="-fPIC"', '--extra-ldflags="-fPIC"',
        '--disable-postproc', '--disable-avfilter', '--disable-sndio',
        '--disable-doc', '--disable-programs', '--disable-ffprobe',
        '--disable-htmlpages', '--disable-manpages', '--disable-podpages',
        '--disable-txtpages', '--disable-ffplay', '--disable-ffmpeg'
    ], cwd='./ffmpeg/')

    print('Compiling FFmpeg for Linux ...')
    subprocess.run(['make', f'-j{threads}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for l_file in glob.glob('ffmpeg/bin/lib/*.so*'):
        shutil.copy2(l_file, l_path)
    for l_file in glob.glob('/usr/lib/libx26*.so'):
        shutil.copy2(l_file, l_path)

    print('Compiling FFmpeg for Linux finished!')


def compile_ffmpeg_windows(a_arch):
    print('Configuring FFmpeg for Windows ...')
    l_path = f'./test_room/addons/gde_gozen/bin/windows_{a_arch}'
    os.environ['PKG_CONFIG_LIBDIR'] = f'/usr/{a_arch}-w64-mingw32/lib/pkgconfig'
    os.environ['PKG_CONFIG_PATH'] = f'/usr/{a_arch}-w64-mingw32/lib/pkgconfig'

    os.makedirs(l_path, exist_ok=True)

    subprocess.run([
        './configure', '--prefix=./bin', '--enable-shared',
        f'--arch={a_arch}', '--target-os=mingw32', '--enable-cross-compile',
        f'--cross-prefix={a_arch}-w64-mingw32-', '--quiet',
        '--extra-libs=-lpthread', '--extra-ldflags="-fpic"',
        '--extra-cflags="-fPIC"',
        '--disable-postproc', '--disable-avfilter', '--disable-sndio',
        '--disable-doc', '--disable-programs', '--disable-ffprobe',
        '--disable-htmlpages', '--disable-manpages', '--disable-podpages',
        '--disable-txtpages', '--disable-ffplay', '--disable-ffmpeg'
    ], cwd='./ffmpeg/')

    print('Compiling FFmpeg for Windows ...')
    subprocess.run(['make', f'-j{threads}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for l_file in glob.glob('ffmpeg/bin/bin/*.dll'):
        shutil.copy2(l_file, l_path)
    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll {l_path}')
    os.system(f'cp /usr/x86_64-w64-mingw32/bin/libstdc++-6.dll {l_path}')

    print('Compiling FFmpeg for Windows finished!')


def compile_ffmpeg_macos(a_arch):
    print('Configuring FFmpeg for MacOS ...')
    l_path_debug = f'./test_room/addons/gde_gozen/bin/macos_{a_arch}/debug/lib'
    l_path_release = f'./test_room/addons/gde_gozen/bin/macos_{a_arch}/release/lib'

    os.makedirs(l_path_debug, exist_ok=True)
    os.makedirs(l_path_release, exist_ok=True)

    subprocess.run([
        './configure', '--prefix=./bin', '--enable-shared',
        f'--arch={a_arch}', '--extra-ldflags="-mmacosx-version-min=10.13"',
        '--quiet', '--extra-cflags="-fPIC -mmacosx-version-min=10.13"',
        '--disable-postproc', '--disable-avfilter', '--disable-sndio',
        '--disable-doc', '--disable-programs', '--disable-ffprobe',
        '--disable-htmlpages', '--disable-manpages', '--disable-podpages',
        '--disable-txtpages', '--disable-ffplay', '--disable-ffmpeg'
    ], cwd='./ffmpeg/')

    print('Compiling FFmpeg for MacOS ...')
    subprocess.run(['make', f'-j{threads}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for l_file in glob.glob('./ffmpeg/bin/lib/*.dylib'):
        shutil.copy2(l_file, l_path_debug)
        shutil.copy2(l_file, l_path_release)

    print('Compiling FFmpeg for MacOS finished!')


def compile_ffmpeg_android(a_arch):
    print('Configuring FFmpeg for Android ...')
    l_path = f'./test_room/addons/gde_gozen/bin/android_{a_arch}'
    l_ndk = os.getenv('ANDROID_NDK')

    if not l_ndk:
        print('ANDROID_NDK environment variable is not set to your NDK path!')
        sys.exit(1)

    os.makedirs(l_path, exist_ok=True)

    subprocess.run([
        './configure', '--prefix=./bin', '--enable-shared', '--arch=arm',
        '--cpu=armv7-a', '--target-os=android', '--enable-pic',
        '--enable-cross-compile', '--extra-cflags="-fPIC"',
        f'--cross-prefix={l_ndk}/toolchains/llvm/prebuilt/linux-{a_arch}/bin/arm-linux-androideabi-',
        f'--sysroot={l_ndk}/toolchains/llvm/prebuilt/linux-{a_arch}/sysroot',
        f'--cc={l_ndk}/toolchains/llvm/prebuilt/linux-{a_arch}/bin/armv7a-linux-androideabi21-clang',
        '--disable-postproc', '--disable-avfilter', '--disable-sndio',
        '--disable-doc', '--disable-programs', '--disable-ffprobe',
        '--disable-htmlpages', '--disable-manpages', '--disable-podpages',
        '--disable-txtpages', '--disable-ffplay', '--disable-ffmpeg'
    ], cwd='./ffmpeg/')

    print('Compiling FFmpeg for Android ...')
    subprocess.run(['make', f'-j{threads}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    # TODO:

    print('Compiling FFmpeg for Android finished!')


def macos_fix(a_arch):
    # This is a fix for the MacOS builds to get the libraries to properly connect to
    # the gdextension library. Without it, the FFmpeg libraries can't be found.
    print('Running fix for MacOS builds ...')

    l_debug_binary = f'./test_room/addons/gde_gozen/bin/macos_{a_arch}/debug/libgozen.macos.template_debug.dev.{a_arch}.dylib'
    l_release_binary = f'./test_room/addons/gde_gozen/bin/macos_{a_arch}/release/libgozen.macos.template_release.{a_arch}.dylib'
    l_debug_bin_folder = f'./test_room/addons/gde_gozen/bin/macos_{a_arch}/debug/lib'
    l_release_bin_folder = f'./test_room/addons/gde_gozen/bin/macos_{a_arch}/release/lib'

    print("Updating @loader_path for MacOS builds")

    if os.path.exists(l_debug_binary):
        for l_file in os.listdir(l_debug_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{l_file} @loader_path/lib/{l_file} {l_debug_binary}')
        subprocess.run(['otool', '-L', l_debug_binary], cwd='./')

    if os.path.exists(l_release_binary):
        for l_file in os.listdir(l_release_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{l_file} @loader_path/lib/{l_file} {l_release_binary}')
        subprocess.run(['otool', '-L', l_release_binary], cwd='./')


def main():
    print('v===================v')
    print('| GDE GoZen builder |')
    print('^===================^')

    if sys.version_info < (3, 10):
        print("Python 3.10+ is required to run this script!")
        sys.exit(2)

    if os_platform.system() == 'Windows':
        # Oh no, Windows detected. ^^"
        subprocess.run([sys.executable, path_build_windows], cwd='./', check=True)
        sys.exit(3)

    match _print_options(title_submodules, [option_no, option_init, option_update]):
        case '2':
            subprocess.run(['git', 'submodule', 'update',
                            '--init', '--recursive'], cwd='./')
        case '3':
            subprocess.run(['git', 'submodule', 'update',
                            '--recursive', '--remote'], cwd='./')

    l_platform = os_linux
    match _print_options(title_platform, [os_linux, os_windows, os_macos, os_android]):
        case '2':
            l_platform = os_windows
        case '3':
            l_platform = os_macos
        case '4':
            l_platform = os_android

    # arm64 isn't supported yet by mingw for Windows, so x86_64 only.
    l_arch = arch_x86_64 if l_platform != os_macos else arch_arm64
    match l_platform:
        case 'linux':
            if _print_options(title_arch, [arch_x86_64, arch_arm64]) == '2':
                l_arch = arch_arm64
        case 'macos':
            if _print_options(title_arch, [arch_arm64, arch_x86_64]) == '2':
                l_arch = arch_x86_64
        case 'android':
            l_arch = arch_arm64

    # When selecting the target, we set dev_build to yes to get more debug info
    # which is helpful when debugging to get something useful of an error msg.
    l_target = target_dev
    l_dev_build = ''
    match _print_options(title_target, [target_dev, target_release]):
        case '2':
            l_target = target_release
        case _:
            l_dev_build = 'dev_build=yes'

    compile_ffmpeg(l_platform, l_arch)
    subprocess.run(['scons', f'-j{threads}', f'target=template_{l_target}', f'platform={l_platform}', f'arch={l_arch}', l_dev_build],
                   cwd='./')

    if l_platform == os_macos:
        macos_fix(l_arch)

    print('\n')
    print('v=========================v')
    print('| Done building GDE GoZen |')
    print('^=========================^')
    print('\n')


if __name__ == '__main__':
    main()
