# GDE GoZen

GDE GoZen uses FFmpeg to get video playback and video seeking working inside of Godot. At this moment there are a couple of limitations which will be fixed in future versions which I'll discuss later in this README file. If you want more information on how this addon works, look in the [test project](https://github.com/VoylinsGamedevJourney/gde_gozen/tree/master/test_room) inside of the repo.

## How to use

This addon is pretty straightforward, put this folder `gde_gozen` inside of a folder called addons inside of your Godot project. You may need to restart you project as the GDExtension which interacts with FFmpeg will probably complain about something. Afterwards you have access to a new node called VideoPlayback. This node has documentation so if you press F1 and search for the node, you'll find it's documentation.

### Video paths

There is a small limitation right now as FFmpeg requires a path to the video file so you can't make the video's part of the exported project and the `res://` paths also don't work. This is just the nature of the beast and not something I can easily solve, but luckily there are solutions! First of all, the video path should be the full path, for testing this is easy as you can make the path whatever you want it to be, for exported projects ... Well, chances of the path being in the exact same location as on your pc are quite low.

The solution for exported projects is to create a folder inside of your exported projects in which you keep the video files, inside of your code you can check if the project is run from the editor or not with: `OS.has_feature(“editor”)`. To get the path of your running project to find the folder where your video's are stored you can use `OS.get_executable_path()`. So it requires a bit of code to get things properly working but everything should work without issues this way.

## FFmpeg libraries

When exporting your projects, take in mind to copy over the library files from the bin folder directly into the folder of the executable. This is needed as Godot does not automatically copy over the library files as it does with the GDExtension file.

For Linux there are some things to take in mind as well. We have the main version which uses the Linux installed FFmpeg libraries, however for some distro's which are not on FFmpeg 6 yet, you will need to use the full version. When developing on a Linux system which doesn't have the correct FFmpeg libraries installed, the only thing you need to do is go into the *.gdextension file inside of the addon and change */bin/linux/* to */bin/linux_full/*. As for exporting you can just change the GDExtension library file inside of the exported project directly without re-exporting your project. If you don't mind about the export size, just include the FFmpeg library files and don't bother with the normal Linux build as it only works for certain distributions (Arch based mainly as others are living in the past with FFmpeg 4).

## Help needed?

You can go to the [GitHub repo](https://github.com/VoylinsGamedevJourney/gde_gozen/issues) to report problems, or visit out [Discord server](discord.gg/BdbUf7VKYC).

> This software uses libraries from the FFmpeg project under the LGPLv2.1

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R4M1UM6)
