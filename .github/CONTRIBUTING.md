# Contributing to the GDE GoZen Project

Thank you for considering contributing to GDE GoZen! It's a bit of a complicated project, especially on the compiling side of things ... and figuring out the FFmpeg side of things, but here's how you can help:

## Items which could always be worked on

Performance on the FFmpeg code can always be improved, same as for adding features to more easily do hardware decoding/encoding. Example projects is something I haven't gotten my hands on yet but I'd like to make some examples - which would replace the test room - for people to test out the different parts of the Addon, such as the audio importer, the rendering system and the video playback itself (which is the main feature of GDE GoZen).

### OS support

OS support is a very difficult subject as I don't have enough funds personally to get Apple hardware, or to get a separate Windows system, ... A Windows VM is something I'm personally using, but that comes with issues for testing hardware decoding/encoding. That's why support is limited to Linux (which I mostly take care of) and Windows (which the community mostly takes care of due to my limited knowledge of Windows/Doors).

Every now and then there is a MacOS developer which contributes a bit but support for MacOS can be unstable so until we find a developer which uses a Mac, or until I have the funds to get some hardware myself, I can't guarantee a smooth experience for Mac users.

## Reporting Issues

If you encounter any bugs, please create an issue in the GitHub repo. We have some templates set up to make this process easier. Be certain to give a debug log, info which might be necessary (branch, OS, FFmpeg version, which binaries - Linux, Linux full, Windows, ...).

## Pull Requests

Before submitting a PR, please ensure following points:
- The code follows to overal project's style;
- Documentation is updated as well if necessary;
- The project still compiles without issues;
