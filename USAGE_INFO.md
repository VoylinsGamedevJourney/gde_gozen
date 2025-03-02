# How to use GDE GoZen

This GDExtension exists in a couple different versions. You can just add the libraries to your project and handle everything yourself or you use the addon version which gives a video playback node to use with the GDExtension libraries. To test out the video playback you can use the test room. **Note** that you need to compile the GDExtension before you can actually use it.

Because this is the core of my video editor there is some extra functionality included by default such as the rendering system. When you have questions, please read the documentation first before reaching out on our [Discord server](https://discord.com/invite/BdbUf7VKYC).

> [!IMPORTANT]
> There is only Linux and Windows support at this moment! MacOS and Android are coming.
> Because of limitations with FFmpeg, web support isn't possible for now.
> Godot 4.3+ is required, the GDExtension could work on older versions but this is not officially supported.

## The addon!

The addon really simplifies the use of this GDExtension, add the `gde_gozen` folder with all its files and binary files to your `addon` folder in your Godot project, and you'll have a new node called `VideoPlayback`. The structure should be `res://addons/gde_gozen/**`, if the files are in the right location you may need to do a restart of your project just in case.

After having added the VideoPlayback node you can or set the path, or you can set the path through code. Take in mind that you just need to set the `path` variable of the node and the video should load. The VideoPlayback node has documentation which you can open from the in-editor docs, which can help a lot as I took the time to nicely document everything. If something isn't fully clear, let me know and I'll see if an update is needed.

### Exporting your projects

Exporting your projects is not too difficult, the only part to keep in mind is to copy the library files into the same folder as your executable as Godot does not copy over those libraries automatically. You can find these library files per platform in the `bin` folder. `linux_full` binaries should be used as some distributions don't support FFmpeg 6+ yet. If you can, you should check if people have FFmpeg 6+ installed so you can use the GDExtension library from the normal `linux` folder instead as it keeps the export size smaller.

There is a GPL version as well of this GDExtension. If you only need VideoPlayback you won't need the GPL version. If you want rendering capabilities you will need to use GPL as some codecs are otherwise missing. Please take in mind, GPL is a license type and when using that version for your software/game, you'll have to switch your license to GPL as well and have your code open source.

## For the DIY people

Since version 4.1 we have three different ways to compile the GDExtension. You can use scons directly, you can compile it through the python script called `build.py` or you can use the [EasyMenu](https://github.com/VoylinsGamedevJourney/easy_menu) file/program. For the people who want to create their own video playback node, well ... Good luck I guess hahah. Just look at how the addon is setup as the Video class only provides the raw yuv data at this stage. If you can't figure things out, stick with the addon ;)

For compiling instructions visit the [COMPILING_INFO.md](https://github.com/VoylinsGamedevJourney/gde_gozen/blob/master/COMPILE_INFO.md).

