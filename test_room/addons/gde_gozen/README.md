# GDE GoZen
## Adding the addon to your project
The GDE GoZen addon is very straightforward, put this folder `gde_gozen` inside of a folder called addons inside of your Godot project. You may need to restart you project as the GDExtension which interacts with FFmpeg will probably complain about something not being fully loaded. After reloading you will have access to a new node called `VideoPlayback`. This node has a lot of documentation comments so if you press F1 inside of Godot and search for the node `VideoPlayback`, you'll find it's documentation and more notes on how to use it.

## Video paths
There is a small limitation right now as FFmpeg requires an absolute path to the video file, so you can't make the video's part of the exported project. The `res://` paths don't work as they aren't absolute paths. This is just the nature of the beast and not something I can easily solve, but luckily there are solutions!

First of all, the video path should be the full path, for testing this is easy as you can make the path whatever you want it to be, for exported projects ... Well, chances of the path being in the exact same location as on your pc are very low.

### Exporting your project
The solution for exported projects is to create a folder inside of your exported projects folder in which you keep the video files. Then inside of your code you can check if the project is run from the editor or not with: `OS.has_feature(“editor”)`. To get the path of your running project to find the folder where your video's are stored you can use `OS.get_executable_path()`. So it requires a bit of code to get things properly working, but everything should work without issues this way.

### FFmpeg libraries
When exporting your projects, take in mind to bundle your executables with the FFmpeg library files which should be present in your exported projects folder.

## Help needed?
You can go to the [GitHub repo](https://github.com/VoylinsGamedevJourney/gde_gozen/issues) to report problems, or visit out [Discord server](discord.gg/BdbUf7VKYC) for help/advice.

> This software uses libraries from the FFmpeg project under the LGPLv2.1

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R4M1UM6)
[GoZen Open Collective page](https://opencollective.com/gozen)
