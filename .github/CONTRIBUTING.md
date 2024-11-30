# Contributing to the GDE GoZen Project

Thank you for considering contributing to GDE GoZen! It's a bit of a complicated project, especially on the compiling side of things ... and figuring out the FFmpeg side of things, but here's how you can help:

## Items which could always be worked on

Performance on the FFmpeg code can always be improved, same as for adding features to more easily do hardware decoding/encoding. Example projects is something I haven't gotten my hands on yet but I'd like to make some examples - which would replace the test room - for people to test out the different parts of the Addon, such as the audio importer, the rendering system and the video playback itself (which is the main feature of GDE GoZen).

### OS support

OS support is a very difficult subject as I don't have enough funds personally to get Mac hardware, or to get a separate Windows system, ... That's why support is limited to Linux (which I mostly take care of) and Windows (which the community mostly takes care of due to my limited knowledge of Windows/Doors).

## Reporting Issues

If you encounter any bugs, please create an issue in the GitHub repo. We have some templates set up to make this process easier. Be certain to give a debug log, info which might be necessary (branch, OS, FFmpeg version, which binaries - Linux, Linux full, Windows, ...).

## Pull Requests

Before submitting a PR, please ensure following points:
- The code follows to overal project's style;
- Documentation is updated as well if necessary;
- The project still compiles without issues;
