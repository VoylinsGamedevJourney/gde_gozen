#!/usr/bin/env python
import os
import platform as os_platform


LIBS_COMMON = [
    "avformat",
    "avcodec",
    "swscale",
    "swresample",
    "avutil"]
LOCATION = "test_room/addons/gde_gozen/bin"

march_flags = {
    "x86_64": "x86-64",
    "arm64": "armv8-a"
}

env = SConscript("godot_cpp/SConstruct")
env.Append(CPPPATH=["src"])
env_suffix = env["suffix"]
env_shlibsuffix = env["SHLIBSUFFIX"]

jobs = ARGUMENTS.get("jobs", 4)
platform = ARGUMENTS.get("platform", "linux")
arch = ARGUMENTS.get("arch", "x86_64")
target = ARGUMENTS.get("target", "template_debug").split("_")[-1]
libpath = f"{LOCATION}/libgozen{env_suffix}{env_shlibsuffix}"

if ARGUMENTS.get("av1", "no") == "yes":
    LIBS_COMMON.append("aom")


if "linux" in platform:
    if arch == "arm64":
        march_flags[arch] = "armv8-a"
        env["CC"] = "aarch64-linux-gnu-gcc"
        env["CXX"] = "aarch64-linux-gnu-g++"
        env["LINK"] = "aarch64-linux-gnu-g++"

    env.Append(
        LINKFLAGS=["-static-libstdc++"],
        CCFLAGS=[f"-march={march_flags[arch]}"],
        CPPFLAGS=[
            "-Iffmpeg/bin",
            "-Iffmpeg/bin/include"],
        LIBPATH=["ffmpeg/bin/lib"],
        LIBS=LIBS_COMMON)

    if ARGUMENTS.get("add_https", "no") == "yes":
        env.Append(LIBS=["gnutls", "nettle", "hogweed", "gmp"])
    if arch != "arm64":
        env.Append(LIBS=["z", "bz2", "lzma"])
    env.Append(LIBS=["m", "pthread", "dl"])
elif "windows" in platform:
    env.Append(
        LINKFLAGS=["-static"],
        LIBS=LIBS_COMMON)
    env.Append(
        CPPPATH=["ffmpeg/bin/include"],
        LIBPATH=["ffmpeg/bin/lib"],
        LIBS=["ws2_32", "bcrypt", "secur32", "shlwapi", "mfuuid", "strmiids"]
    )
elif "macos" in platform:
    # NOTE: MacOS can only be build on a MacOS machine!
    if arch == "x86_64":
        env.Append(CCFLAGS=["-arch", "x86_64"], LINKFLAGS=["-arch", "x86_64"])
    elif arch == "arm64":
        env.Append(CCFLAGS=["-arch", "arm64"], LINKFLAGS=["-arch", "arm64"])

    env.Append(
        CPPPATH=["ffmpeg/bin/include"],
        LIBPATH=[
            "ffmpeg/bin/lib",
            "/usr/local/lib"],
        LIBS=LIBS_COMMON,
        LINKFLAGS=[  # macOS-specific linking flags
            "-stdlib=libc++",
            "-framework", "CoreFoundation",
            "-framework", "CoreVideo",
            "-framework", "CoreMedia",
            "-framework", "AVFoundation",
            "-framework", "Security",      # Often needed by static FFmpeg
            "-framework", "AudioToolbox"]  # Often needed by static FFmpeg
    )
    env.Append(LIBS=["z", "bz2", "iconv", "m", "pthread"])
elif "android" in platform:
    if arch == "arm64":
        env.Append(CCFLAGS=["-march=armv8-a"])
    elif arch == "armv7a":
        env.Append(CCFLAGS=["-march=armv7-a", "-mfloat-abi=softfp", "-mfpu=neon"])

    env.Append(
        LINKFLAGS=["-static-libstdc++"],
        CPPFLAGS=[
            "-Iffmpeg/bin",
            "-Iffmpeg/bin/include"],
        LIBPATH=["ffmpeg/bin/lib"],
        LIBS=LIBS_COMMON)
    env.Append(LIBS=["z", "m", "log"])
elif "web" in platform:
    web_bin_path = libpath
    web_include_path = f"{web_bin_path}/include"

    env.Append(
        CPPPATH=[web_include_path],
        LIBPATH=[web_bin_path],
        LIBS=LIBS_COMMON,
        CCFLAGS=["-pthread"],
        LINKFLAGS=[
            "-pthread",
            "-sUSE_PTHREADS=1",
            "-sSHARED_MEMORY=1",
            "-sALLOW_MEMORY_GROWTH=1",
            "-sSIDE_MODULE=1",
        ]
    )
else:
    print(f"Warning: Unsupported platform '{platform}' in SConstruct.")


# Godot compiling stuff
src = Glob("src/*.cpp")
sharedlib = env.SharedLibrary(libpath, src)
Default(sharedlib)
