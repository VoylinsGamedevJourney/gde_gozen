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
    "--disable-bzlib",
    "--disable-lzma",
    # Hardware decoders
    "--disable-vaapi",
    "--disable-vdpau",
    "--disable-cuda",
    "--disable-cuvid",
    "--disable-nvenc",
    # Others
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


def compile_ffmpeg(platform: str, arch: str, add_av1: bool = False, add_https: bool = False) -> None:
    if os.path.exists("./ffmpeg/ffbuild/config.mak"):
        print("Cleaning FFmpeg...")
        subprocess.run(["make", "distclean"], cwd="./ffmpeg/")
        subprocess.run(["rm", "-rf", "bin"], cwd="./ffmpeg/")

    if platform == OS_LINUX:
        compile_ffmpeg_linux(arch, add_av1, add_https)
    elif platform == OS_WINDOWS:
        compile_ffmpeg_windows(arch, add_av1, add_https)
    elif platform == OS_MACOS:
        compile_ffmpeg_macos(arch, add_av1, add_https)
    elif platform == OS_ANDROID:
        compile_ffmpeg_android(arch, add_https)
    elif platform == OS_WEB:
        compile_ffmpeg_web()


def compile_ffmpeg_linux(arch: str, add_av1: bool = False, add_https: bool = False) -> None:
    print("Configuring FFmpeg for Linux ...")
    os.environ["PKG_CONFIG_PATH"] = "/usr/lib/pkgconfig"

    cmd = [
        "./configure",
        "--prefix=./bin",
        "--disable-shared",
        "--enable-static",
        "--enable-pic",
        "--disable-asm",
        f"--arch={arch}",
        "--target-os=linux",
        "--quiet",
        "--enable-pthreads",
        "--extra-cflags=-fPIC",
        "--enable-libvpx",
    ]
    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if add_av1:
        cmd += ENABLE_AV1

    if arch == "arm64":
        cmd += [
            "--enable-cross-compile",
            "--cross-prefix=aarch64-linux-gnu-",
            "--cc=aarch64-linux-gnu-gcc"]
    if add_https:
        cmd += [
            "--enable-protocol=https",
            "--enable-protocol=tls",
            "--enable-gnutls"]

    if subprocess.run(cmd, cwd="./ffmpeg/").returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for Linux ...")
    if subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)
    if subprocess.run(["make", "install"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)


def compile_ffmpeg_windows(arch: str, add_av1: bool = False, add_https: bool = False) -> None:
    print("Configuring FFmpeg for Windows ...")
    os.environ["PKG_CONFIG_LIBDIR"] = f"/usr/{arch}-w64-mingw32/lib/pkgconfig"
    os.environ["PKG_CONFIG_PATH"] = f"/usr/{arch}-w64-mingw32/lib/pkgconfig"

    cmd = [
        "./configure",
        "--prefix=./bin",
        "--disable-shared",
        "--enable-static",
        "--enable-pic",
        "--disable-asm",
        f"--arch={arch}",
        "--target-os=mingw32",
        "--enable-cross-compile",
        f"--cross-prefix={arch}-w64-mingw32-",
        "--quiet",
        "--extra-libs=-lpthread",
        "--extra-ldflags=-static",
        "--extra-cflags=-fPIC",
        "--enable-libvpx",
    ]
    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if add_av1:
        cmd += ENABLE_AV1
    if add_https:
        cmd += [
            "--enable-schannel",
            "--enable-protocol=https",
            "--enable-protocol=tls"]

    result = subprocess.run(cmd, cwd="./ffmpeg/")
    if result.returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for Windows ...")
    if subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/").returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)
    if subprocess.run(["make", "install"], cwd="./ffmpeg/").returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)

    print("Compiling FFmpeg for Windows finished!")


def compile_ffmpeg_macos(arch: str, add_av1: bool = False, add_https: bool = False) -> None:
    print("Configuring FFmpeg for MacOS ...")
    cmd = [
        "./configure",
        "--prefix=./bin",
        "--disable-shared",
        "--enable-static",
        "--enable-pic",
        "--disable-asm",
        f"--arch={arch}",
        "--quiet",
        "--extra-ldflags=-mmacosx-version-min=10.13",
        "--extra-cflags=-fPIC -mmacosx-version-min=10.13",
        "--disable-lzma",
        "--enable-libvpx",
    ]
    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if add_av1:
        cmd += ENABLE_AV1
    if add_https:
        cmd += [
            "--enable-securetransport",
            "--enable-protocol=https",
            "--enable-protocol=tls"]

    result = subprocess.run(cmd, cwd="./ffmpeg/")
    if result.returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for MacOS ...")
    if subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)
    if subprocess.run(["make", "install"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)

    print("Compiling FFmpeg for MacOS finished!")


def compile_ffmpeg_android(arch: str, add_https: bool = False) -> None:
    print("Configuring FFmpeg for Android ...")
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
        target_arch = "aarch64-linux-android"
        arch_flags = "-march=armv8-a"
        ffmpeg_arch = "aarch64"
    else:  # armv7a
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
        "--disable-shared",
        "--enable-static",
        "--disable-asm",
        "--enable-pic",
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
        # Adding decoders
        "--enable-decoder=aac",
        "--enable-decoder=aac_latm",
        "--enable-decoder=mp3",
        "--enable-decoder=mp3float",
        "--enable-decoder=pcm_s16le",
        "--enable-decoder=opus",
        "--enable-decoder=vorbis",
        # Adding parsers
        "--enable-parser=aac",
        "--enable-parser=aac_latm",
        "--enable-parser=mpegaudio",
        "--enable-parser=opus",
        "--enable-parser=vorbis",
    ]

    cmd += ENABLED_MODULES
    cmd += DISABLED_MODULES

    if arch == ARCH_ARMV7A:
        cmd += ["--disable-vulkan"]

    result = subprocess.run(cmd, cwd="./ffmpeg/")
    if result.returncode != 0:
        print("Error: FFmpeg failed!")

    print("Compiling FFmpeg for Android ...")
    if subprocess.run(["make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)
    if subprocess.run(["make", "install"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)

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

    path: str = "./test_room/addons/gde_gozen/"
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
    if subprocess.run(["emmake", "make", f"-j{THREADS}"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)
    if subprocess.run(["emmake", "make", "install"], cwd="./ffmpeg/", check=True).returncode != 0:
        print("Error: FFmpeg failed!")
        sys.exit(1)

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
    av1_support: bool = False
    https_support: bool = False

    match _print_options("Select platform", [OS_LINUX, OS_WINDOWS, OS_MACOS, OS_ANDROID, OS_WEB]):
        case 2:
            platform = OS_WINDOWS
        case 3:
            platform = OS_MACOS
            if _print_options(title_arch, [ARCH_ARM64, ARCH_X86_64]) == 2:
                arch = ARCH_X86_64
            else:
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
    if _print_options("Clean Scons?", ["yes", "no"]) == 1:
        clean_scons = True

    if _print_options("(Re)compile ffmpeg?", ["yes", "no"]) == 1:
        av1_support = _print_options("Add AV1 support?", ["no", "yes"]) == 2
        if platform in [OS_MACOS, OS_WINDOWS]:
            https_support = _print_options("Add https support? (native)", ["no", "yes"]) == 2
        elif platform == OS_LINUX:
            https_support = _print_options("Add https support? (gnutls)", ["no", "yes"]) == 2
        compile_ffmpeg(platform, arch, av1_support, https_support)

    # Godot requires arm32 instead of armv7a.
    if arch == ARCH_ARMV7A:
        arch = "arm32"

    env = os.environ.copy()
    cmd = ["scons", f"-j{THREADS}", f"target=template_{target}", f"platform={platform}",
           f"arch={arch}", f"av1={'yes' if av1_support else 'no'}",
           f"add_https={'yes' if https_support else 'no'}"]

    if platform == OS_ANDROID:
        # We need to check if ANDROID_HOME is set to the sdk folder.
        if os.getenv("ANDROID_HOME") is None:
            if os_platform.system() == "Linux":
                print("Linux detected for setting ANDROID_HOME")
                env["ANDROID_HOME"] = os.getenv("ANDROID_HOME", ANDROID_SDK_PATH)

    if clean_scons:
        clean_cmd = ["scons", "--clean", f"-j{THREADS}", f"target=template_{target}",
                     f"platform={platform}", f"arch={arch}",
                     f"av1={'yes' if av1_support else 'no'}",
                     f"add_https={'yes' if https_support else 'no'}"]
        subprocess.run(clean_cmd, cwd="./", env=env)

    subprocess.run(cmd, cwd="./", env=env)
    update_csharp_bins()

    print("")
    print("v=========================v")
    print("| Done building GDE GoZen |")
    print("^=========================^")
    print("")


if __name__ == "__main__":
    main()
