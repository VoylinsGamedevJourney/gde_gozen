#!/usr/bin/env python
"""
GDE GoZen Builder Script

This script handles the compilation of FFmpeg and the GDE GoZen plugin
for multiple platforms and architectures.

Windows and Linux can be build on Linux or Windows with WSL.
For MacOS you need to use MacOS itself else building fails.

For Web you need Emscripten installed.
You may also need to custom build the Godot web export debug/release template with:
`scons platform=web target=template_debug use_llvm=yes threads_enabled=yes dlink_enabled=yes\
extra_web_link_flags="-sINITIAL_MEMORY=1024MB -sSTACK_SIZE=5MB -sALLOW_MEMORY_GROWTH=1 -sUSE_PTHREADS=1" -j10`
"""

import os
import sys
import platform as os_platform
import subprocess
import glob
import shutil


THREADS: int = os.cpu_count() or 4
PATH_BUILD_WINDOWS: str = "build_on_windows.py"

ARCH_X86_64: str = "x86_64"
ARCH_ARM64: str = "arm64"  # armv8
ARCH_ARMV7A: str = "armv7a"
ARCH_WASM32: str = "wasm32"

OS_LINUX: str = "linux"
OS_WINDOWS: str = "windows"
OS_MACOS: str = "macos"
OS_ANDROID: str = "android"
OS_WEB: str = "web"

TARGET_DEV: str = "debug"
TARGET_RELEASE: str = "release"

# WARNING: Change the path to you android sdk!
ANDROID_SDK_PATH: str = "/opt/android-sdk"
ANDROID_API_LEVEL: int = 24

ENABLED_MODULES = [
    "--enable-swscale",

    "--enable-demuxer=ogg",
    "--enable-demuxer=matroska,webm",
]

ENABLE_AV1 = [
    "--enable-libaom",
    "--enable-decoder=av1",
    "--enable-parser=av1",
]

DISABLED_MODULES = [
    "--disable-muxers",
    "--disable-encoders",
    "--disable-postproc",
    "--disable-avdevice",
    "--disable-avfilter",
    "--disable-sndio",
    "--disable-doc",
    "--disable-programs",
    "--disable-ffprobe",
    "--disable-htmlpages",
    "--disable-manpages",
    "--disable-podpages",
    "--disable-txtpages",
    "--disable-ffplay",
    "--disable-ffmpeg",
    "--disable-hwaccels",
]


def _print_options(title: str, options: list[str]) -> int:
    # Helper function to print options and get the input.
    i: int = 1
    print(f"{title}:")

    for option in options:
        if i == 1:
            print(f"{i}. {option}; (default)")
        else:
            print(f"{i}. {option};")
        i += 1

    user_input: str = input("> ")

    if user_input.strip() == "":
        return 1

    try:
        return int(user_input)
    except ValueError:
        print("Invalid input. Using default option (1).")
        return 1


def get_ndk_host_tag() -> str:
    match os_platform.system().lower():
        case "linux": return "linux-x86_64"
        case "darwin": return "darwin-x86_64"
        case "windows": return "windows-x86_64"
        case _:
            print(f"Invalid host system: {os_platform.system()}")
            sys.exit(2)


def compile_ffmpeg(platform: str, arch: str, add_av1: bool = False) -> None:
    if os.path.exists("./ffmpeg/ffbuild/config.mak"):
        print("Cleaning FFmpeg...")
        subprocess.run(["make", "distclean"], cwd="./ffmpeg/")
        subprocess.run(["rm", "-rf", "bin"], cwd="./ffmpeg/")

    if platform == OS_LINUX:
        compile_ffmpeg_linux(arch, add_av1)
    elif platform == OS_WINDOWS:
        compile_ffmpeg_windows(arch, add_av1)
    elif platform == OS_MACOS:
        compile_ffmpeg_macos(arch, add_av1)
    elif platform == OS_ANDROID:
        compile_ffmpeg_android(arch)
    elif platform == OS_WEB:
        compile_ffmpeg_web()


def compile_ffmpeg_linux(arch: str, add_av1: bool = False) -> None:
    print("Configuring FFmpeg for Linux ...")
    path: str = f"./test_room/addons/gde_gozen/bin/linux_{arch}"
    path_csharp: str = f"./test_room_csharp/addons/gde_gozen/bin/linux_{arch}"
    os.environ["PKG_CONFIG_PATH"] = "/usr/lib/pkgconfig"

    os.makedirs(path, exist_ok=True)
    os.makedirs(path_csharp, exist_ok=True)

    cmd = [
        "./configure",
        "--prefix=./bin",
        "--enable-shared",
        f"--arch={arch}",
        "--target-os=linux",
        "--quiet",
        "--enable-pic",
        "--enable-pthreads",
        "--extra-cflags=-fPIC",
        "--extra-ldflags=-fPIC",
    ]
    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if add_av1:
        cmd += ENABLE_AV1

    if arch == "arm64":
        cmd += [
            "--enable-cross-compile",
            "--cross-prefix=aarch64-linux-gnu-",
            "--cc=aarch64-linux-gnu-gcc",
        ]

    if subprocess.run(cmd, cwd="./ffmpeg/").returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for Linux ...")
    subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True)
    subprocess.run(["make", "install"], cwd="./ffmpeg/", check=True)

    copy_linux_dependencies(path, arch, add_av1)
    copy_linux_dependencies(path_csharp, arch, add_av1)


def copy_linux_dependencies(path: str, arch: str, add_av1: bool = False):
    print("Copying lib files ...")
    for file in glob.glob("ffmpeg/bin/lib/*.so.*"):
        if file.count(".") == 2:
            shutil.copy2(file, path)

    if add_av1:
        # AOM lib.
        for file in glob.glob("/usr/lib/libaom.so*"):
            if file.count(".") == 2:
                shutil.copy2(file, path)
        # AOM lib for Ubuntu.
        if arch == ARCH_X86_64:
            for file in glob.glob("/usr/lib/x86_64*/libaom.so*", recursive=True):
                if file.count(".") == 2:
                    shutil.copy2(file, path)
        else:
            for file in glob.glob("/usr/lib/aarch64*/libaom.so*", recursive=True):
                shutil.copy2(file, path)

    print("Compiling FFmpeg for Linux finished!")


def compile_ffmpeg_windows(arch: str, add_av1: bool = False) -> None:
    print("Configuring FFmpeg for Windows ...")
    path: str = f"./test_room/addons/gde_gozen/bin/windows_{arch}"
    path_csharp: str = f"./test_room_csharp/addons/gde_gozen/bin/windows_{arch}"
    os.environ["PKG_CONFIG_LIBDIR"] = f"/usr/{arch}-w64-mingw32/lib/pkgconfig"
    os.environ["PKG_CONFIG_PATH"] = f"/usr/{arch}-w64-mingw32/lib/pkgconfig"

    os.makedirs(path, exist_ok=True)
    os.makedirs(path_csharp, exist_ok=True)

    cmd = [
        "./configure",
        "--prefix=./bin",
        "--enable-shared",
        f"--arch={arch}",
        "--target-os=mingw32",
        "--enable-cross-compile",
        f"--cross-prefix={arch}-w64-mingw32-",
        "--quiet",
        "--extra-libs=-lpthread",
        "--extra-ldflags=-fpic",
        "--extra-cflags=-fPIC",
    ]
    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if add_av1:
        cmd += ENABLE_AV1

    result = subprocess.run(cmd, cwd="./ffmpeg/")
    if result.returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for Windows ...")
    subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/")
    subprocess.run(["make", "install"], cwd="./ffmpeg/")

    print("Copying lib files ...")
    for file in glob.glob("ffmpeg/bin/bin/*.dll"):
        shutil.copy2(file, path)
        shutil.copy2(file, path_csharp)

    # Somehow some distro"s put the dll"s in bin, and others in lib.
    if os.path.exists("/usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll"):
        subprocess.run(["cp", "/usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll", path], check=True)
        subprocess.run(["cp", "/usr/x86_64-w64-mingw32/bin/libwinpthread-1.dll", path_csharp], check=True)

        if add_av1:
            subprocess.run(["cp", "/usr/x86_64-w64-mingw32/bin/libaom.dll", path], check=True)
            subprocess.run(["cp", "/usr/x86_64-w64-mingw32/bin/libaom.dll", path_csharp], check=True)
    else:
        subprocess.run(["cp", "/usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll", path], check=True)
        subprocess.run(["cp", "/usr/x86_64-w64-mingw32/lib/libwinpthread-1.dll", path_csharp], check=True)

        if add_av1:
            subprocess.run(["cp", "/usr/x86_64-w64-mingw32/lib/libaom.dll", path], check=True)
            subprocess.run(["cp", "/usr/x86_64-w64-mingw32/lib/libaom.dll", path_csharp], check=True)

    print("Compiling FFmpeg for Windows finished!")


def compile_ffmpeg_macos(arch: str, add_av1: bool = False) -> None:
    print("Configuring FFmpeg for MacOS ...")
    path_debug: str = "./test_room/addons/gde_gozen/bin/macos/debug/lib"
    path_release: str = "./test_room/addons/gde_gozen/bin/macos/release/lib"
    path_debug_csharp: str = "./test_room_csharp/addons/gde_gozen/bin/macos/debug/lib"
    path_release_csharp: str = "./test_room_csharp/addons/gde_gozen/bin/macos/release/lib"

    os.makedirs(path_debug, exist_ok=True)
    os.makedirs(path_release, exist_ok=True)
    os.makedirs(path_debug_csharp, exist_ok=True)
    os.makedirs(path_release_csharp, exist_ok=True)

    cmd = [
        "./configure",
        "--prefix=./bin",
        "--enable-shared",
        f"--arch={arch}",
        "--quiet",
        "--extra-ldflags=-mmacosx-version-min=10.13",
        "--extra-cflags=-fPIC -mmacosx-version-min=10.13",
    ]
    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if add_av1:
        cmd += ENABLE_AV1

    result = subprocess.run(cmd, cwd="./ffmpeg/")
    if result.returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for MacOS ...")
    subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True)
    subprocess.run(["make", "install"], cwd="./ffmpeg/", check=True)

    print("Copying lib files ...")
    for file in glob.glob("./ffmpeg/bin/lib/*.dylib"):
        shutil.copy2(file, path_debug)
        shutil.copy2(file, path_release)
        shutil.copy2(file, path_debug_csharp)
        shutil.copy2(file, path_release_csharp)

    print("Compiling FFmpeg for MacOS finished!")


def compile_ffmpeg_android(arch: str) -> None:
    print("Configuring FFmpeg for Android ...")
    path: str = "./test_room/addons/gde_gozen/bin/android_"
    path_csharp: str = "./test_room_csharp/addons/gde_gozen/bin/android_"
    ndk: str = os.getenv("ANDROID_NDK_ROOT")

    if not ndk:
        ndk = os.getenv("ANDROID_NDK")
    if not ndk or not os.path.isdir(ndk):
        print("ANDROID_NDK(_ROOT) environment variable is not set or invalid!")
        sys.exit(1)

    # Getting correct settings.
    host_tag: str = get_ndk_host_tag()
    target_arch: str = ""
    arch_flags: str = ""
    ffmpeg_arch: str = ""
    strip_tool: str = ""

    if arch == ARCH_ARM64:
        path += "arm64"
        path_csharp += "arm64"
        target_arch = "aarch64-linux-android"
        arch_flags = "-march=armv8-a"
        ffmpeg_arch = "aarch64"
    else:  # armv7a
        path += "arm32"
        path_csharp += "arm32"
        target_arch = "armv7a-linux-androideabi"
        arch_flags = "-march=armv7-a -mfloat-abi=softfp -mfpu=neon"
        ffmpeg_arch = "arm"

    main_folder: str = f"{ndk}/toolchains/llvm/prebuilt/{host_tag}"
    toolchain_bin: str = f"{main_folder}/bin"
    toolchain_sysroot: str = f"{main_folder}/sysroot"
    cc: str = f"{toolchain_bin}/{target_arch}{ANDROID_API_LEVEL}-clang"
    cxx: str = f"{toolchain_bin}/{target_arch}{ANDROID_API_LEVEL}-clangxx"
    strip_tool: str = f"{toolchain_bin}/llvm-strip"

    cmd = [
        "./configure",
        "--prefix=./bin",
        "--enable-shared",
        f"--arch={ffmpeg_arch}",
        "--target-os=android",
        "--enable-pic",
        "--enable-cross-compile",
        f"--cc={cc}",
        f"--cxx={cxx}",
        f"--sysroot={toolchain_sysroot}",
        f"--strip={strip_tool}",
        "--extra-cflags=-fPIC",
        f"--extra-ldflags={arch_flags}",
    ]
    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if arch == ARCH_ARMV7A:
        cmd += ["--disable-vulkan"]

    result = subprocess.run(cmd, cwd="./ffmpeg/")
    if result.returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for Android ...")
    subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True)
    subprocess.run(["make", "install"], cwd="./ffmpeg/", check=True)

    print("Copying lib files ...")
    os.makedirs(path, exist_ok=True)
    os.makedirs(path_csharp, exist_ok=True)

    for file in glob.glob("ffmpeg/bin/lib/*.so*"):
        shutil.copy2(file, path)
        shutil.copy2(file, path_csharp)

    print("Compiling FFmpeg for Android finished!")


def compile_ffmpeg_web() -> None:
    # NOTE: No C# support yet for web builds.
    print("Install/activate emsdk ...")
    subprocess.run(["emsdk/emsdk", "install", "3.1.64"], check=True)
    subprocess.run(["emsdk/emsdk", "activate", "3.1.64"], check=True)

    emsdk_output = subprocess.check_output(
        ["bash", "-c", "source ./emsdk/emsdk_env.sh && env"], text=True)

    for line in emsdk_output.splitlines():
        key, _, value = line.partition("=")
        os.environ[key] = value

    print("Configuring FFmpeg for Web ...")

    path: str = "./test_room/addons/gde_gozen/bin/web"
    target_include_dir: str = f"{path}/include"
    ffmpeg_bin_dir: str = "ffmpeg/bin"
    ffmpeg_lib_dir: str = f"{ffmpeg_bin_dir}/lib"
    ffmpeg_include_dir: str = f"{ffmpeg_bin_dir}/include"

    os.makedirs(path, exist_ok=True)

    cmd = [
        "emconfigure",
        "./configure",
        "--cc=emcc",
        "--cxx=em++",
        "--ar=emar",
        "--ranlib=emranlib",
        "--nm=emnm",
        "--enable-static",
        "--disable-shared",
        "--prefix=./bin",
        "--enable-cross-compile",
        "--target-os=none",
        "--arch=wasm32",
        "--cpu=generic",
        "--disable-asm",
        "--extra-cflags=-O3 -msimd128 -DNDEBUG -pthread -sUSE_PTHREADS=1 -sASYNCIFY=1 -fPIC",
        "--extra-ldflags=-O3 -msimd128 -pthread -sUSE_PTHREADS=1 -sALLOW_MEMORY_GROWTH=1 -sASYNCIFY=1 -fPIC -sWASM_BIGINT=1",
        "--enable-pic",
        "--enable-small",
        "--disable-everything",

        "--enable-avcodec",
        "--enable-avformat",
        "--enable-avutil",
        "--enable-swscale",
        "--enable-swresample",
        "--enable-network",

        "--enable-demuxer=mov,mp4,m4a,3gp,3g2,mj2",
        "--enable-demuxer=matroska,webm",
        "--enable-demuxer=aac",

        "--enable-decoder=vp9",
        "--enable-decoder=h264",
        "--enable-decoder=opus",
        "--enable-decoder=pcm_s16le",
        "--enable-decoder=aac",

        "--enable-parser=h264",
        "--enable-parser=aac",
        "--enable-parser=opus",
        "--enable-parser=vorbis",
        "--enable-parser=mpegaudio",
        "--enable-parser=vp9",

        "--enable-bsf=h264_mp4toannexb",
        "--enable-bsf=aac_adtstoasc",
        "--enable-bsf=extract_extradata",
        "--enable-bsf=noise",

        "--enable-protocol=file,http",
    ]
    cmd += DISABLED_MODULES

    print(f"Running cmd: {cmd}")
    result = subprocess.run(cmd, cwd="./ffmpeg/", check=True)
    if result.returncode != 0:
        print("Error: FFmpeg configure failed for Emscripten!")
        sys.exit(1)

    print("Compiling FFmpeg for Web (using emmake)...")
    subprocess.run(["emmake", "make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True)
    subprocess.run(["emmake", "make", "install"], cwd="./ffmpeg/", check=True)

    print("Copying static lib files (.a) ...")
    for file in glob.glob(os.path.join(ffmpeg_lib_dir, "*.a")):
        print(f"Copying {file} to {path}")
        shutil.copy2(file, path)

    if os.path.exists(target_include_dir):
        shutil.rmtree(target_include_dir)
    shutil.copytree(ffmpeg_include_dir, target_include_dir)

    print("Compiling FFmpeg for Web finished!")


def update_csharp_bins():
    for root, _, files in os.walk("test_room"):
        for file in files:
            if file.startswith('libgozen'):
                rel_path = os.path.relpath(root, "test_room")
                dst_dir = os.path.join("test_room_csharp", rel_path)

                os.makedirs(dst_dir, exist_ok=True)
                shutil.copy2(os.path.join(root, file), os.path.join(dst_dir, file))


def macos_fix(arch: str) -> None:
    # This is a fix for the MacOS builds to get the libraries to properly connect to
    # the gdextension library. Without it, the FFmpeg libraries can"t be found.
    print("Running fix for MacOS builds ...")

    debug_binary: str = f"./test_room/addons/gde_gozen/bin/macos/debug/libgozen.macos.template_debug.{arch}.dylib"
    release_binary: str = f"./test_room/addons/gde_gozen/bin/macos/release/libgozen.macos.template_release.{arch}.dylib"
    debug_bin_folder: str = "./test_room/addons/gde_gozen/bin/macos/debug/lib"
    release_bin_folder: str = "./test_room/addons/gde_gozen/bin/macos/release/lib"

    debug_binary_csharp: str = f"./test_room_csharp/addons/gde_gozen/bin/macos/debug/libgozen.macos.template_debug.{arch}.dylib"
    release_binary_csharp: str = f"./test_room_csharp/addons/gde_gozen/bin/macos/release/libgozen.macos.template_release.{arch}.dylib"
    debug_bin_folder_csharp: str = "./test_room_csharp/addons/gde_gozen/bin/macos/debug/lib"
    release_bin_folder_csharp: str = "./test_room_csharp/addons/gde_gozen/bin/macos/release/lib"

    print("Updating @loader_path for MacOS builds")

    if os.path.exists(debug_binary) and os.path.exists(debug_binary_csharp):
        for file in os.listdir(debug_bin_folder):
            print("Fixing file ", file)
            subprocess.run(["install_name_tool", "-change", f"./bin/lib/{file}", f"@loader_path/lib/{file}", debug_binary], check=True)

        for file in os.listdir(debug_bin_folder_csharp):
            print("Fixing file ", file)
            subprocess.run(["install_name_tool", "-change", f"./bin/lib/{file}", f"@loader_path/lib/{file}", debug_binary_csharp], check=True)

        print("Fixing folder ", debug_binary, " & ", debug_binary_csharp)

        subprocess.run(["otool", "-L", debug_binary], cwd="./")
        subprocess.run(["otool", "-L", debug_binary_csharp], cwd="./")
    else:
        print("No debug folder found for MacOS!")

    if os.path.exists(release_binary) and os.path.exists(release_binary_csharp):
        for file in os.listdir(release_bin_folder):
            print("Fixing file ", file)
            subprocess.run(["install_name_tool", "-change", f"./bin/lib/{file}", f"@loader_path/lib/{file}", release_binary], check=True)

        for file in os.listdir(release_bin_folder_csharp):
            print("Fixing file ", file)
            subprocess.run(["install_name_tool", "-change", f"./bin/lib/{file}", f"@loader_path/lib/{file}", release_binary_csharp], check=True)

        print("Fixing folder ", release_binary, " & ", release_binary_csharp)

        subprocess.run(["otool", "-L", release_binary], cwd="./")
        subprocess.run(["otool", "-L", release_binary_csharp], cwd="./")
    else:
        print("No release folder found for MacOS!")


def main():
    print("v===================v")
    print("| GDE GoZen builder |")
    print("^===================^")

    if sys.version_info < (3, 10):
        print("Python 3.10+ is required to run this script!")
        sys.exit(2)

    if os_platform.system() == "Windows":
        # Oh no, Windows detected. ^^"
        subprocess.run([sys.executable, PATH_BUILD_WINDOWS], cwd="./", check=True)
        sys.exit(3)

    if os.path.exists("./ffmpeg/ffbuild/config.mak"):
        match _print_options("Init/Update submodules", ["no", "initialize", "update"]):
            case 2:
                subprocess.run(["git", "submodule", "update",
                                "--init", "--recursive"], cwd="./")
            case 3:
                subprocess.run(["git", "submodule", "update",
                                "--recursive", "--remote"], cwd="./")
    else:
        subprocess.run(["git", "submodule", "update", "--init", "--recursive"], cwd="./")

    # Arm64 isn"t supported yet by mingw for Windows, so x86_64 only.
    title_arch: str = "Choose architecture"
    platform: str = OS_LINUX
    arch: str = ARCH_X86_64
    match _print_options("Select platform", [OS_LINUX, OS_WINDOWS, OS_MACOS, OS_ANDROID, OS_WEB]):
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
        case 5:
            platform = OS_WEB
            arch = ARCH_WASM32
        case _:  # Linux
            if _print_options(title_arch, [ARCH_X86_64, ARCH_ARM64]) == 2:
                arch = ARCH_ARM64

    target: str = TARGET_DEV
    if _print_options("Select target", [TARGET_DEV, TARGET_RELEASE]) == 2:
        target = TARGET_RELEASE

    clean_scons = False
    if _print_options("Clean Scons?", ["no", "yes"]) == 2:
        clean_scons = True

    if _print_options("(Re)compile ffmpeg?", ["no", "yes"]) == 2:
        compile_ffmpeg(platform, arch, _print_options("Add AV1 support?", ["no", "yes"]) == 2)

    # Godot requires arm32 instead of armv7a.
    if arch == ARCH_ARMV7A:
        arch = "arm32"


    cmd = ["scons", f"-j{THREADS}", f"target=template_{target}", f"platform={platform}", f"arch={arch}"]
    env = os.environ.copy()

    if platform == OS_ANDROID:
        # We need to check if ANDROID_HOME is set to the sdk folder.
        if os.getenv("ANDROID_HOME") is None:
            if os_platform.system() == "Linux":
                print("Linux detected for setting ANDROID_HOME")
                env["ANDROID_HOME"] = os.getenv("ANDROID_HOME", ANDROID_SDK_PATH)

    if clean_scons:
        clean_cmd = ["scons", "--clean", f"-j{THREADS}", f"target=template_{target}", f"platform={platform}", f"arch={arch}"]
        subprocess.run(clean_cmd, cwd="./", env=env)

    subprocess.run(cmd, cwd="./", env=env)

    update_csharp_bins()

    if platform == OS_MACOS:
        macos_fix(arch)

    print("")
    print("v=========================v")
    print("| Done building GDE GoZen |")
    print("^=========================^")
    print("")


if __name__ == "__main__":
    main()
