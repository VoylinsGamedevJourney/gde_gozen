# GDE GoZen
## Adding the addon to your project
The GDE GoZen addon is very straightforward, put this folder `gde_gozen` inside of a folder called addons inside of your Godot project. You may need to restart you project as the GDExtension which interacts with FFmpeg will probably complain about something not being fully loaded. After reloading you will have access to a new node called `VideoPlayback`. This node has a lot of documentation comments so if you press F1 inside of Godot and search for the node `VideoPlayback`, you'll find it's documentation and more notes on how to use it.

## Exporting your project
When exporting your project, you will need to be careful of the way that you add your video files to your project. They can not be inside of your executable file and have to be added separately in a folder inside of your exported projects. Then inside of your code you can check if the project is run from the editor or not with: `OS.has_feature(“editor”)`.

To get the path of your running project to find the folder where your video's are stored you can use `OS.get_executable_path()`. So it requires a bit of code to get things properly working, but everything should work without issues this way.

We do globalize the path so if the structure is the same as in your `res://` folder, than there shouldn't be an issue.

### FFmpeg libraries
When exporting your projects, take in mind to bundle your executables with the FFmpeg library files which should be present in your exported projects folder.

## Help needed?
You can go to the [GitHub repo](https://github.com/VoylinsGamedevJourney/gde_gozen/issues) to report problems, or visit out [Discord server](discord.gg/BdbUf7VKYC) for help/advice.

> This software uses libraries from the FFmpeg project under the LGPLv2.1

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R4M1UM6)
