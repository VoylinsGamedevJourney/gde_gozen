# Compiling GDE GoZen
For the people who need extra help, feel free to watch [this video](https://youtu.be/62smFmZyekg). Some things have changed since that video and I got rid of the EasyMenu program support due to maintaining multiple way's to build GDE GoZen was time consuming.

> [!TIP]
> Compiling the GDExtension for every platform you want to support can be time consuming, if you don't want to compile the GDExtension yourself **and** want to easily get new compiled builds on new version releases of GDE GoZen then you can always get the addon from [my ko-fi page](https://ko-fi.com/s/c6ec85052b) and from [itch.io](https://voylin.itch.io/gde-gozen-video-playback-addon-for-godot).

## Compiling
### Prerequisites
The build process needs to be done through the terminal. There is no other way of compiling it 
Install python 3, scons, and git! You will also need to initialize the submodules of the git repo with `git submodule update --init --recursive`. Updating the submodules can be done with `git submodule update --recursive --remote`.

For AV1 support you'll need aom installed on your machine.

### Building
To start compiling the GDExtension, run `python3 build.py`. You'll need to select the options you want and to select for which platform and architecture you want to build GDE GoZen for. The building does take some time as you will need to compile both FFmpeg and the GDExtension. However, the build.py script makes everything very straightforward. Do remember though that you will need to say yes to compiling FFmpeg, without FFmpeg this won't work.

#### For building on Windows
For Window builds you will need WSL installed, without this you won't be able to compile FFmpeg or the GDExtension.
If you are building for Windows on WSL and you need AV1 support, you will need to compile lib aom with mingw on your WSL install first. 

#### For Windows builds
I recommend compiling on a Linux system since it'll go a lot smoother, just be certain to install mingw. If you want AV1 support you should compile lib aom with mingw. Some distro's such as Arch Linux can install lib aom with mingw through the AUR which speeds things up.

#### For MacOS builds
Due to MacOS being made by Apple, you will need an MacOS device for making the compiling work. There isn't much I can do about this sadly enough and compiled builds may also need their library files to be approved by the user before the GDExtension becomes accepted/usable on the MacOS system.

For compiling GDE GoZen with AV1 support, you will need to install aom and pkg-config through brew.

#### For Web builds
Web builds are only partially working. There is no audio support, no AV1 support, no access to system files due to Godot web builds running in a sandbox, and performance is a lower compared to the other platform support. When compiling for Web you will need to follow the instructions which are in the comments in the `build.py` file.

Web builds aren't included in the official builds because of these reasons. Preferably you should use the build in Theora video playback which Godot provides.

#### For Android builds
Android builds need to make certain that permissions are set correctly when using. You will need Android-studio or install the SDK's manually. The compiling environment with emsdk should get setup correctly. Do note that building this is only possible on Linux. If you're on Windows, you have to use a VM or WSL. If you can export your Godot projects to Android already, than compiling GDE GoZen may work without issues. I'm by no means an Android developer so for problems compiling I would suggest creating an issue in the repo.

## Struggling and need help?

You can join our Discord server to ask for help, but before joining the [Discord server](https://discord.com/invite/BdbUf7VKYC) because compiling doesn't work, **please** check if your submodules are properly initialized. If you run into some issues after trying, feel free to ask for help in the [Discord server](https://discord.com/invite/BdbUf7VKYC) in the `gozen-video-editor` channel.

### Error: ./configure can't be found
This error is most likely due to not having initialized the submodules. Check the FFmpeg folder to see if it's empty or not. Empty = not initialized. Not empty = Create an issue as something might be wrong (but show a screenshot of the not empty folder for confirmation).


> [!CAUTION]
> At this moment only Linux, Windows, Web, MacOS, and Android are supported! Compiling on Windows, however, may come with some challenges and may not always work if you don't have the correct tools installed such as python, scons, git, ... Also, compiling on MacOS can only be done by using a MacOS system. Compiling Android comes with challenges of setting up your system correctly and is generally advised to do this on a Linux machine.

> [!NOTE]
> If you compile with AV1 support, you'll have to manually copy the libaom from the addons/bin/* folder to your exported project. This is due to the `gozen.gdextension` file being made without av1 support in mind. That's the file responsible for copying over the libaries on export.
