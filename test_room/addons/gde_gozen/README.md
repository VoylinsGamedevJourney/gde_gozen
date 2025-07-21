# GDE GoZen
## Adding the addon to your project
The GDE GoZen addon is very straightforward, put this folder `gde_gozen` inside of a folder called addons inside of your Godot project. You may need to restart you project as the GDExtension which interacts with FFmpeg will probably complain about something not being fully loaded. After reloading you will have access to a new node called `VideoPlayback`. This node has a lot of documentation comments so if you press F1 inside of Godot and search for the node `VideoPlayback`, you'll find it's documentation and more notes on how to use it.

Since version 8.0 it's possible to add and play videos from your project directly. What you would need to adjust however is to add `mp4` and any other video extensions you might use to your Editor settings in `docks/filesystem/other_file_extensions` so they show up in your file explorer.

## Exporting your project
When exporting your projects, take in mind to bundle your executables with the FFmpeg library files which should be present in your exported projects folder.

## Help needed?
You can go to the [GitHub repo](https://github.com/VoylinsGamedevJourney/gde_gozen/issues) to report problems, or visit out [Discord server](discord.gg/BdbUf7VKYC) for help/advice.

> This software uses libraries from the FFmpeg project under the LGPLv2.1

[![ko-fi](https://ko-fi.com/img/githubbutton_sm.svg)](https://ko-fi.com/R6R4M1UM6)
