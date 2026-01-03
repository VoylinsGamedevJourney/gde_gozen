# GDE GoZen
## Adding the addon to your project
Put this folder, `gde_gozen`, inside of a folder called `addons` inside of your Godot project and re-open your project. After reloading you will have access to a new node, `VideoPlayback`. This node has a lot of documentation comments so by pressing F1 inside Godot and search for the node `VideoPlayback`, you'll find it's documentation and more notes on how to use it.

## Videos in the file tree
To see video files in your projects file tree, you need to add `mp4` and any other video extensions you might use to your Editor settings in `docks/filesystem/other_file_extensions`.

## Exporting your project
1. When exporting, you'll have your executable and the GDE GoZen library file, these do need to be both shared for the application to work.
2. Also, you will have to add `*.mp4` and other extension names of your video files to the resources which need to get exported for each platform you want to export for, otherwise your video files will not be included in your final export.

## Help needed?
You can go to the [GitHub repo](https://github.com/VoylinsGamedevJourney/gde_gozen/issues) to report problems, or visit out [Discord server](discord.gg/BdbUf7VKYC) for help/advice.

> This software uses libraries from the FFmpeg project under the LGPLv2.1

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R4M1UM6)
