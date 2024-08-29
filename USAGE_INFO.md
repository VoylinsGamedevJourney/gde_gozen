# How to use GDE GoZen

Using this GDExtension is not as straightforward as just putting it into your project, selecting a playback node and finished. This plugin is mainly intended for using inside of the GoZen video editor but as you can see in the test_room you can use it perfectly fine for video playback. Please look at the test room project and this document before submitting issues or asking unnecessary questions in the Discord server.

> IMPORTANT
> Version 3 brought a lot of changes which will break previous implementations!

## The addon!

The addon really simplifies the use of this GDExtension, as before it would take you a lot of steps to set everything up properly and to actually get stuff working. Now it's a simple addon which you add the your folder ... That's it :p.

The structure should be `res://addons/gde_gozen/**`, if the files are in the right location you may need to do a restart of your project just in case.

### Exporting your projects

For exporting your project there is a little thing to keep in mind with Windows, when exporting your project the GDExtension library will copy to the export folder, but this does not happen for the FFmpeg libraries. These need to manually be copied into the same folder as the GDExtension library and project executable.

For Linux there are some things to take in mind as well. We have the main version which uses the Linux installed FFmpeg libraries, however for some distro's which are not on FFmpeg 6 yet, you will need to use the full version. When developing on a Linux system which doesn't have the correct FFmpeg libraries installed, the only thing you need to do is go into the *.gdextension file inside of the addon and change */bin/linux/* to */bin/linux_full/*. As for exporting you can just change the GDExtension library file inside of the exported project. Don't forget to also add the FFmpeg library files from the bin folder of the addon to the export folder to make things work when using the full Linux build.

## For the DIY people

Since version 3 there is an addon to use the video player, this greatly helps in providing video playback in your projects. But for the people who want to create their own video playback node, well ... Good luck I guess hahah. Just look at how the addon is setup as the Video class only provides the raw yuv data at this stage. If you can't figure things out, stick with the addon ;)

### Renderer

At this moment still a lot of changes are happening to the GDExtension and the Renderer and Video class are still being heavily developed, especially to allow for hardware decoding/encoding. That's why this info is lacking at the moment, more proper documentation will come but will probably be included in the class documentation itself which can be viewed from within Godot when the time comes.

