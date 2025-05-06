import os
import sys
import platform as os_platform
import subprocess
import glob
import shutil
import tempfile

# Uncaught (in promise) RuntimeError: WebAssembly.instantiate():
# data segment 0 is out of bounds (offset 10862752, length 24278784,
# memory size 33554432)

# Windows and Linux can be build on Linux or Windows with WSL.
# For MacOS you need to use MacOS itself else building fails.

# For Web you need Emscripten installed.
# `emsdk/emsdk install latest`
# `emsdk/emsdk activate latest`
# `source emsdk/emsdk_env.sh`
# You may also need to custom build the Godot web export debug/release template with:
# `scons platform=web target=template_debug use_llvm=yes dlink_enabled=yes extra_web_link_flags="-sINITIAL_MEMORY=1024MB -sSTACK_SIZE=5MB -sALLOW_MEMORY_GROWTH=1" -j10`


THREADS: int = os.cpu_count() or 4

PATH_BUILD_WINDOWS: str = 'build_on_windows.py'

OPTION_DEBUG: str = 'debug'
OPTION_RELEASE: str = 'release'

ARCH_X86_64: str = 'x86_64'
ARCH_ARM64: str = 'arm64'
ARCH_ARMV7A: str = 'armv7a'

OS_LINUX: str = 'linux'
OS_WINDOWS: str = 'windows'
OS_MACOS: str = 'macos'
OS_ANDROID: str = 'android'
OS_WEB: str = 'web'

TARGET_DEV: str = 'debug'
TARGET_RELEASE: str = 'release'

ANDROID_API_LEVEL: int = 24

DISABLES = [
    '--disable-encoders',
    '--disable-muxers',

    '--disable-postproc',
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
    '--disable-ffmpeg'
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


def compile_ffmpeg(platform, arch) -> None:
    if _print_options('(Re)compile ffmpeg?', ['yes', 'no']) == 2:
        return

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
    elif platform == OS_WEB:
        if shutil.which('emcc') is None:
            print('Error: Emscripten SDK not found/activated!')
            sys.exit(-1)
        compile_ffmpeg_web()


def compile_ffmpeg_linux(arch: str) -> None:
    print('Configuring FFmpeg for Linux ...')
    path: str = f'./test_room/addons/gde_gozen/bin/linux_{arch}'
    os.environ['PKG_CONFIG_PATH'] = '/usr/lib/pkgconfig'

    os.makedirs(path, exist_ok=True)

    command = [
        './configure',
        '--prefix=./bin',
        '--enable-shared',
        f'--arch={arch}',
        '--target-os=linux',
        '--quiet',
        '--enable-pic',
        '--extra-cflags=-fPIC',
        '--extra-ldflags=-fPIC'
    ]
    command += DISABLES

    result = subprocess.run(command, cwd='./ffmpeg/')
    if result.returncode != 0:
        print('Error: FFmpeg failed!')

    print('Compiling FFmpeg for Linux ...')
    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for file in glob.glob('ffmpeg/bin/lib/*.so.*'):
        if file.count('.') == 2:
            shutil.copy2(file, path)
    for file in glob.glob('/usr/lib/libx26*.so.*'):
        shutil.copy2(file, path)

    print('Compiling FFmpeg for Linux finished!')


def compile_ffmpeg_windows(arch) -> None:
    print('Configuring FFmpeg for Windows ...')
    path: str = f'./test_room/addons/gde_gozen/bin/windows_{arch}'
    os.environ['PKG_CONFIG_LIBDIR'] = f'/usr/{arch}-w64-mingw32/lib/pkgconfig'
    os.environ['PKG_CONFIG_PATH'] = f'/usr/{arch}-w64-mingw32/lib/pkgconfig'

    os.makedirs(path, exist_ok=True)

    command = [
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
        '--extra-cflags=-fPIC'
    ]
    command += DISABLES

    result = subprocess.run(command, cwd='./ffmpeg/')
    if result.returncode != 0:
        print('Error: FFmpeg failed!')

    print('Compiling FFmpeg for Windows ...')
    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for file in glob.glob('ffmpeg/bin/bin/*.dll'):
        shutil.copy2(file, path)
    os.system(f'cp /usr/{arch}-w64-mingw32/bin/libwinpthread-1.dll {path}')
    os.system(f'cp /usr/{arch}-w64-mingw32/bin/libstdc++-6.dll {path}')

    print('Compiling FFmpeg for Windows finished!')


def compile_ffmpeg_macos(arch) -> None:
    print('Configuring FFmpeg for MacOS ...')
    path_debug: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/debug/lib'
    path_release: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/release/lib'

    os.makedirs(path_debug, exist_ok=True)
    os.makedirs(path_release, exist_ok=True)

    command = [
        './configure',
        '--prefix=./bin',
        '--enable-shared',
        f'--arch={arch}',
        '--extra-ldflags=-mmacosx-version-min=10.13',
        '--quiet',
        '--extra-cflags=-fPIC -mmacosx-version-min=10.13',
    ]
    command += DISABLES

    result = subprocess.run(command, cwd='./ffmpeg/')
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


def compile_ffmpeg_android(arch) -> None:
    print('Configuring FFmpeg for Android ...')
    path: str = f'./test_room/addons/gde_gozen/bin/android_{arch}'
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
        target_arch = 'aarch64-linux-android'
        arch_flags = '-march=armv8-a'
        ffmpeg_arch = 'aarch64'
    else:  # armv7a
        target_arch = 'armv7a-linux-androideabi'
        arch_flags = '-march=armv7-a -mfloat-abi=softfp -mfpu=neon'
        ffmpeg_arch = 'arm'

    main_folder: str = f'{ndk}/toolchains/llvm/prebuilt/{host_tag}'
    toolchain_bin: str = f'{main_folder}/bin'
    toolchain_sysroot: str = f'{main_folder}/sysroot'
    cc: str = f'{toolchain_bin}/{target_arch}{ANDROID_API_LEVEL}-clang'
    cxx: str = f'{toolchain_bin}/{target_arch}{ANDROID_API_LEVEL}-clangxx'
    strip_tool: str = f'{toolchain_bin}/llvm-strip'

    command = [
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
        f'--extra-ldflags={arch_flags}'
    ]
    command += DISABLES

    result = subprocess.run(command, cwd='./ffmpeg/')
    if result.returncode != 0:
        print('Error: FFmpeg failed!')

    print('Compiling FFmpeg for Android ...')
    subprocess.run(['make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['make', 'install'], cwd='./ffmpeg/')

    print('Copying lib files ...')
    for file in glob.glob('ffmpeg/bin/lib/*.so*'):
        shutil.copy2(file, path)

    print('Compiling FFmpeg for Android finished!')


def compile_ffmpeg_web() -> None:
    print('Configuring FFmpeg for Web ...')
    path: str = './test_room/addons/gde_gozen/bin/web'
    os.makedirs(path, exist_ok=True)

    command = [
        'emconfigure',
        './configure',
        '--cc=emcc',
        '--cxx=em++',
        '--ar=emar',
        '--ranlib=emranlib',
        '--nm=emnm',
        '--enable-static',
        '--disable-shared',
        '--prefix=./bin',
        '--enable-cross-compile',
        '--extra-cflags=-pthread -sUSE_PTHREADS=1 -fPIC',
        '--extra-ldflags=-pthread -sUSE_PTHREADS=1 -fPIC',
        '--enable-pic',

        '--disable-pthreads',
        '--disable-w32threads',
        '--disable-os2threads',

        '--disable-muxers',
        '--disable-encoders',
        '--disable-devices',
        '--disable-filters',

        '--disable-asm',
        '--disable-hwaccels',
        '--disable-vulkan',
        '--disable-alsa',
        '--disable-libxcb',
        '--disable-libxcb-shm',
        '--disable-libxcb-shape',
        '--disable-libxcb-xfixes',
        '--disable-xlib',
        '--disable-sdl2',
        '--disable-iconv',
        '--disable-zlib',
        '--disable-bzlib',
    ]
    command += DISABLES

    ffmpeg_bin_dir: str = 'ffmpeg/bin'
    ffmpeg_lib_dir: str = f'{ffmpeg_bin_dir}/lib'
    ffmpeg_include_dir: str = f'{ffmpeg_bin_dir}/include'
    target_include_dir: str = f'{path}/include'

    print(f'Running command: {' '.join(command)}')
    result = subprocess.run(command, cwd='./ffmpeg/')
    if result.returncode != 0:
        print('Error: FFmpeg configure failed for Emscripten!')
        sys.exit(1)

    print('Compiling FFmpeg for Web (using emmake)...')
    subprocess.run(['emmake', 'make', f'-j{THREADS}'], cwd='./ffmpeg/')
    subprocess.run(['emmake', 'make', 'install'], cwd='./ffmpeg/')

    # print('Copying static lib files (.a) ...')
    # for file in glob.glob(os.path.join(ffmpeg_lib_dir, '*.a')):
    #     print(f'Copying {file} to {path}')
    #     shutil.copy2(file, path)

    print('Combining FFmpeg static lib files (.a) ...')
    create_combined_library(ffmpeg_lib_dir, path)

    if os.path.exists(target_include_dir):
        shutil.rmtree(target_include_dir)
    shutil.copytree(ffmpeg_include_dir, target_include_dir)

    print('Compiling FFmpeg for Web finished!')


def create_combined_library(ffmpeg_lib_dir: str, output_dir: str) -> None:
    abs_ffmpeg_lib_dir = os.path.abspath(ffmpeg_lib_dir)
    abs_output_dir = os.path.abspath(output_dir)

    print(f'Looking for libraries in resolved path: {abs_ffmpeg_lib_dir}')
    print(f'Output directory resolved to: {abs_output_dir}')

    lib_files = glob.glob(os.path.join(abs_ffmpeg_lib_dir, '*.a'))
    temp_dir_obj = tempfile.mkdtemp(prefix='ffmpeg_combine_')
    os.makedirs(abs_output_dir, exist_ok=True)

    all_objects = []
    has_errors = False
    try:
        for lib_file_abs in lib_files:
            lib_name = os.path.basename(lib_file_abs)
            print(f'Extracting objects from {lib_name} into {temp_dir_obj}...')
            try:
                result = subprocess.run(
                    ['emar', 'x', lib_file_abs],
                    cwd=temp_dir_obj,
                    check=True,
                    capture_output=True,
                    text=True
                )
            except subprocess.CalledProcessError as e:
                print(f'Error extracting {lib_name}:')
                print(f'Return code: {e.returncode}')
                has_errors = True
            except FileNotFoundError:
                print('Error: "emar" command not found. Is Emscripten environment activated and in PATH?')
                raise

        if has_errors:
            print('Errors occurred during extraction. Combined library might be incomplete.')

        print(f'Collecting object files from {temp_dir_obj}...')
        for item in os.listdir(temp_dir_obj):
            item_path = os.path.join(temp_dir_obj, item)
            if os.path.isfile(item_path) and item.endswith('.o'):
                all_objects.append(item_path)  # Append absolute path

        combined_lib = os.path.join(abs_output_dir, 'libffmpeg_combined.a')
        print(f'Creating combined library: {combined_lib} with {len(all_objects)} object files.')

        if os.path.exists(combined_lib):
            print(f'Removing existing combined library: {combined_lib}')
            os.remove(combined_lib)

        print('Running emar crs command...')
        try:
            cmd = ['emar', 'crs', combined_lib] + all_objects
            result = subprocess.run(cmd, check=True, capture_output=True, text=True)
            print(f'Combined library created successfully at {combined_lib}')

        except subprocess.CalledProcessError as e:
            cmd_short = f'{' '.join(e.cmd[:5])} ... ({len(e.cmd)} total args)'
            print('Error creating combined library:')
            print(f'Return code: {e.returncode}')
            raise e
        except FileNotFoundError:
            print('Error: "emar" command not found. Is Emscripten environment activated and in PATH?')
            raise

    finally:
        if 'temp_dir_obj' in locals() and os.path.exists(temp_dir_obj):
            print(f'Cleaning up temporary directory: {temp_dir_obj}')
            try:
                shutil.rmtree(temp_dir_obj)
            except OSError as e:
                print(f'Warning: Could not remove temporary directory {temp_dir_obj}: {e}')


def macos_fix(arch) -> None:
    # This is a fix for the MacOS builds to get the libraries to properly connect to
    # the gdextension library. Without it, the FFmpeg libraries can't be found.
    print('Running fix for MacOS builds ...')

    debug_binary: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/debug/libgozen.macos.template_debug.dev.{arch}.dylib'
    release_binary: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/release/libgozen.macos.template_release.{arch}.dylib'
    debug_bin_folder: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/debug/lib'
    release_bin_folder: str = f'./test_room/addons/gde_gozen/bin/macos_{arch}/release/lib'

    print('Updating @loader_path for MacOS builds')

    if os.path.exists(debug_binary):
        for file in os.listdir(debug_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {debug_binary}')
        subprocess.run(['otool', '-L', debug_binary], cwd='./')

    if os.path.exists(release_binary):
        for file in os.listdir(release_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {release_binary}')
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

    match _print_options('Init/Update submodules', ['no', 'initialize', 'update']):
        case 2:
            subprocess.run(['git', 'submodule', 'update',
                            '--init', '--recursive'], cwd='./')
        case 3:
            subprocess.run(['git', 'submodule', 'update',
                            '--recursive', '--remote'], cwd='./')

    platform: str = OS_LINUX
    match _print_options('Select platform', [OS_LINUX, OS_WINDOWS, OS_MACOS, OS_ANDROID, OS_WEB]):
        case 2: platform = OS_WINDOWS
        case 3: platform = OS_MACOS
        case 4: platform = OS_ANDROID
        case 5: platform = OS_WEB

    # arm64 isn't supported yet by mingw for Windows, so x86_64 only.
    # Web does not need any architecture
    title_arch: str = 'Choose architecture'
    arch: str = ARCH_X86_64 if platform != OS_MACOS else ARCH_ARM64
    match platform:
        case 'linux':
            if _print_options(title_arch, [ARCH_X86_64, ARCH_ARM64]) == 2:
                arch = ARCH_ARM64
        case 'macos':
            if _print_options(title_arch, [ARCH_ARM64, ARCH_X86_64]) == 2:
                arch = ARCH_X86_64
        case 'android':
            if _print_options(title_arch, [ARCH_ARM64, ARCH_ARMV7A]) == 2:
                arch = ARCH_ARMV7A
            else:
                arch = ARCH_ARM64
        case 'web':
            arch = 'wasm32'

    # When selecting the target, we set dev_build to yes to get more debug info
    # which is helpful when debugging to get something useful of an error msg.
    target: str = TARGET_DEV
    dev_build: str = ''
    match _print_options('Select target', [TARGET_DEV, TARGET_RELEASE]):
        case 2:
            target = TARGET_RELEASE
        case _:
            dev_build = 'dev_build=yes'

    compile_ffmpeg(platform, arch)

    cmd = ['scons', f'-j{THREADS}', f'target=template_{target}', f'platform={platform}', dev_build, f'arch={arch}']

    if platform == OS_ANDROID:
        # We need to check if ANDROID_HOME is set to the sdk folder.
        android_home: str = ''
        if os.getenv('ANDROID_HOME') is None:
            if os_platform.system() == 'Linux':
                print('Linux detected for setting ANDROID_HOME')
                android_home = 'ANDROID_HOME=/opt/android-sdk'
        cmd += f'{android_home}'

    subprocess.run(cmd, cwd='./')

    if platform == OS_MACOS:
        macos_fix(arch)

    print('')
    print('v=========================v')
    print('| Done building GDE GoZen |')
    print('^=========================^')
    print('')


if __name__ == '__main__':
    main()
