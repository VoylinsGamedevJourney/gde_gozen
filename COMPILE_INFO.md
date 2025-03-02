# Compiling GDE GoZen

> [!TIP]
> If you don't want to compile the GDExtension yourself **and** want to easily receive the updates of GDE GoZen then you can always get the addon on [my ko-fi page](https://ko-fi.com/s/c6ec85052b) and on [itch.io](https://voylin.itch.io/gde-gozen-video-playback-addon-for-godot). These compiled versions get updated with every release, so you don't have to spend your time, electricity and pc resources on compiling. With the added benefit that you are helping to fund this project, which is very much appreciated! :D

Compiling this GDExtension can be done in three different ways:
- Using the python file `build.py`;
- Using the command line and scons;

For the people who need extra help, feel free to watch this video:
https://youtu.be/62smFmZyekg

## Before you do anything

Install python, scons, and git! Also, initialize the submodules of the git repo with `git submodule update --init --recursive`. Updating the submodules can be done with `git submodule update --recursive --remote`. Without doing this you'll get errors that the scons file could not be found.

## Using build.py

For this, and all other options, you need Python3 (minimum Python 3.10) and scons installed on your system. Also update the git submodules! To compile it's pretty straight forward, just run the script inside your terminal (on Windows use Powershell) with the command `python build.py` or `python3 build.py` depending on your distribution and OS. After that you'll be asked several questions for how you want to compile the GDExtension, enter the numbers of the selection you want and press enter.

There is an option for using the system FFmpeg, if the system does not have FFmpeg installed (Version 6+) you should not use the system install and you'll have to compile FFmpeg libraries from scratch to accompany the GDExtension file. Note that this is only applicable for Linux users! For Windows you don't have a choice as the FFmpeg libraries need to be included for it to work as there are no globally installed FFmpeg libraries.

> [!NOTE]
> When you build GDE GoZen for the first time, it'll take a good amount of time. Also make certain that you are compiling the FFmpeg libraries as this is necessary for things to work!

## Using the command line

Using the command line is pretty straightforward, but I ask that if you never compiled with the command line before and don't want to learn how to do this, that you please use the build.py option.

First up you'd need to compile the FFmpeg libraries, for this you can download them somewhere online, or compile them by looking at the build.py file to see which flags I used. You **Need** the FFmpeg libraries else the GDE won't compile!

To compile the GDE itself from the command line use `scons` with the default Godot compile commands afterwards:
- `-j<number of threads>`: multi-threaded compiling;
- `target=<template>`: is specificially for Godot, so use or `template_debug` or `template_release`;
- `platform=<OS>`: `linux` or `windows` are supported right now, other platforms such as `macos`, `android`, and `web` aren't yet supported;
- `arch=<architecture>`: only supported architecture is `x86_64`, no guarantee that `x86_32`, `arm64`, `arm32` and `rv64` work.

## Struggling and need help?

> [!CAUTION]
> At this moment only Linux and Windows are supported! Compiling on Windows, however, may come with some challenges and may not always work if you don't have the correct tools installed such as python, scons, git, ...

You can join our Discord server to ask for help, but before joining the [Discord server](https://discord.com/invite/BdbUf7VKYC) because compiling doesn't work, **please** check if your submodules are properly initialized. If you run into some issues after trying, feel free to ask for help in the [Discord server](https://discord.com/invite/BdbUf7VKYC) in the `gozen-video-editor` channel.

