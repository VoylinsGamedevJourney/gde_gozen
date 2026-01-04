# Compiling GDE GoZen
For the people who need extra help, feel free to watch [this video](https://youtu.be/62smFmZyekg). Some things have changed since that video and I got rid of the EasyMenu program support due to maintaining multiple way's to build GDE GoZen was time consuming.

> [!TIP]
> Compiling the GDExtension for every platform you want to support can be time consuming, if you don't want to compile the GDExtension yourself **and** want to easily get new compiled builds on new version releases of GDE GoZen then you can always get the addon from [my ko-fi page](https://ko-fi.com/s/c6ec85052b) and from [itch.io](https://voylin.itch.io/gde-gozen-video-playback-addon-for-godot).

## Compiling
### Prerequisites
The build process needs to be done through the terminal.
1. Install **python 3**, **scons**, and **git**;
2. If you want the C# version, ensure you have the **.NET SDK** installed;
3. If building on Windows you will need **WSL** installed and clone the repo through WSL directly;
4. Initialize the submodules of the git repo with `git submodule update --init --recursive`. Updating the submodules can be done with `git submodule update --recursive --remote`;

For AV1 support you'll need aom installed on your machine.

### Building
To start compiling the GDExtension, run `python3 build.py`. You'll need to select the options you want and to select for which platform and architecture you want to build GDE GoZen for.

The `build.py` script makes everything pretty straightforward:
1. It will compile **FFmpeg** (this is required and does take a fair amount of time);
2. It will compile the **GDExtension** itself;
3. It will automatically copy the compiled binaries to both GDE GoZen addon folders in both `test_room` and `test_room_csharp`;

Do note that you will need to build both **Debug** and **Release** for using it in the Godoe editor and have the GDExtension compiled for each platform for exporting your game/application to those specific platforms.

During compiling you might get a warning about an argument given not existing in scons. This is an argument for `av1` compiling and can be safely ignored.

#### For building on Windows
For Window builds you will need WSL installed, without this you won't be able to compile FFmpeg or the GDExtension.
*   If you are building for Windows on WSL and you need AV1 support, you will need to compile lib aom with mingw on your WSL install first.
*   The `build.py` script will detect Windows and attempt to guide you through WSL usage.

#### For Windows builds (Target platform)
I recommend compiling on a Linux system (or WSL) since it'll go a lot smoother. Be certain to install `mingw-w64`.

#### For MacOS builds
Due to MacOS being made by Apple, you will need an MacOS device for making the compiling work. There isn't much I can do about this sadly enough and compiled builds may also need their library files to be approved by the user before the GDExtension becomes accepted/usable on the MacOS system.

*   For compiling GDE GoZen with AV1 support, you will need to install `aom` and `pkg-config` through brew.

#### For Web builds
Web builds are only partially working. There is no audio support, no AV1 support, no access to system files due to Godot web builds running in a sandbox, and performance is a lower compared to the other platform support. When compiling for Web you will need to follow the instructions which are in the comments in the `build.py` file.

*   **Limitations:** Web builds currently have no audio support and no access to system files (due to sandbox).
*   **Performance:** Lower compared to native platforms.
*   **C# Support:** Not currently implemented for Web builds.

Due to the limitations, it's advised to use Godot's build in Theora video playback support. Web builds aren't included in the official builds because of these reasons.

#### For Android builds
You will need the Android SDK/NDK installed.
*   Update the `ANDROID_SDK_PATH` in `build.py` to match your system.
*   Building is recommended on Linux (or WSL).
*   If you can export your Godot projects to Android already, compiling GDE GoZen will likely work, provided `ANDROID_HOME` or `ANDROID_NDK_ROOT` are set in your environment variables.

## Struggling and need help?
First of all, did you read everything correctly and took a moment to think for yourself why things might not be working? Too many times do people ask for help without having read things through or having taken a step back to think why the instructions might not work for them.
You can join our Discord server to ask for help, but before joining the [Discord server](https://discord.com/invite/BdbUf7VKYC) because compiling doesn't work, **please** check if your submodules are properly initialized. If you run into some issues after trying, feel free to ask for help in the [Discord server](https://discord.com/invite/BdbUf7VKYC) in the `gozen` channel.

### Error: ./configure can't be found
This error is most likely due to not having initialized the submodules. Check the FFmpeg folder to see if it's empty or not. Empty = not initialized. Not empty = Create an issue as something might be wrong (but show a screenshot of the not empty folder for confirmation).

On Windows this is most likely due to having cloned the repo from Windows and not WSL, this makes the end of lines in the FFmpeg repo incorrect for WSL to read the `configure` file correctly. Windows uses `\r\n` (CRLF) and Linux/MacOS uses `\n` (LF). You can update the repo with this command if you run into this issue on Windows: `git config core.autocrlf input`

### Error: Can't compile through WSL
Make certain that `mingw-w32` is not installed! Having this one installed can give issues and might make compiling FFmpeg not work.
