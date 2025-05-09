# Changelog
This is the changelog of all releases which can be found on the [GDE GoZen repo release page](https://github.com/VoylinsGamedevJourney/gde_gozen/releases)

## Version 6.1 - 2025/05/10
- *Fix:* Video not loading when path had been set;
- *Fix:* Videos with thumbnails not loading;
- *Fix:* `update_video` throwing error of texture size being wrong;
- *Fix:* Error when getting first frame;
- *Add:* Feature request issue template;
- *Add:* Globalize paths (res:// and user:// can now be used);
- *Add:* Beginning for Web export;
- *Add:* Clean scons option on build.py;
- *Improved:* FFmpeg library size;
- *Improved:* The whole repo got an update for the .md files;
- *Improved:* Improved `update_video` to accept audio;
- *Improved:* Smaller export size;
- *Improved:* Scons file;
- *Improved:* Workflow update;
- *Removed:* `dev_build` from scons command;
- *Removed:* Error codes file;
- *Removed:* Compute shader;

## Version 6.0 - 2025/04/21
### Fixes
- *Fix:* Compile on macos by @felixbaral in #38
- *Fix:* For missing libraries for Windows on export;
- *Fix:* Error for image dimension being bad;
- *Fix:* For older Python versions;
- *Fix:* Framerate mistake;
- *Fix:* For wrong color support;
### Additions
- *Add:* Added MacOS support;
- *Add:* Added basics for Android support (Can't find anybody to test if it works or not);
### Improvements
- *Improved:* Video load times;
- *Improved:* Implemented RAII for the GDExtension side of things;
- *Improved:* Updated Test room to Godot 4.4;
- *Improved:* Updated the test room itself with a load video button;
And some other code readability improvements with minor fixes ;)

## Version 5.0 - 2025/03/09
Mac OS support is nearly complete, just some more testing which needs to be done. As we don't have any Mac OS testers at the moment there's a lack of knowing if things actually function correctly or not. The Mac OS stuff got implemented by following some updates of a PR from felixbaral so hopefully I didn't mess anything up.

Reason why I couldn't just merge that PR directly was because the build system had already changed too much compared to what the PR was based upon.
### Fixes
- *Fix:* Error of multiple signal binding;
- *Fix:* `video_ended` signal mistake;
- *Fix:* Build system for compiling on Windows; (with WSL)
- *Fix:* Removed Web support mentions from the project due to FFmpeg not being able to be compiled for web;
- *Fix:* Removed rendering; (this will be moved to another GDE due to the need not being high enough and the licensing becoming complicated to keep this in the main GDE GoZen)
- *Fix:* Removed EasyMenu for compiling as it wasn't up to date and the build.py script became good enough;
- *Fix:* Removed minimal Linux build; (needing to rely on people having the correct FFmpeg version installed isn't the best solution)
### Additions
- *Add:* Added playback speed control;
- *Add:* Adding pitch adjust for speed control;
- *Add:* Added an autoplay option;
- *Add:* Added a loop option;
- *Add:* Better performance for loading in Audio; (by removing seeking at beginning)
- *Add:* Some performance improvements in video playback;
- *Add:* Updated documentation;
- *Add:* A better build script for compiling;
- *Add:* Some renaming of functions and signal names;
- *Add:* OS updates
- *Add:* Added Linux ARM support;
- *Add:* Possibility that Mac support is working; (We don't have any testers atm who can confirm if the Mac build works or not)

## Version 4.1 - 2024/11/30
### Fixes
- *Fix:* Color range fix; (There was a problem with dark not being dark and light now being light)
- *Fix:* Fixed a couple of compile errors for Windows;
- *Fix:* HW decoding for Vulkan (Hardware decoding still has some overall issues which I'm working on);
- *Fix:* Problems on first startup with addon;
### Additions
- *Add:* Renderer class;
- *Add:* Global errors;
- *Add:* Enable audio toggle;
- *Add:* GPL v3 build;
- *Add:* Added an audio class to easily convert audio to WAV 16 bit;
- *Add:* Added a separate FFmpeg class for handling some FFmpeg specific functions;
- *Add:* Added Avio_audio to see data in memory as file;
- *Add:* Added EasyMenu compile menu;
- *Add:* Added SECURITY;
- *Add:* Added CODE_OF_CONDUCT;
- *Add:* Added CONTRIBUTING;
- *Add:* Started adding code to compile for MacOS (Not working and not supported yet!!);
### Improvements
- *Improved:* Compile info got a much needed update;
- *Improved:* Usage info also got a much needed update;
- *Improved:* Added the GPL v3 license for the GPL builds;
- *Improved:* Workflows got some extra additions;
- *Improved:* Build system got cleaned up;
- *Improved:* Python script build.py got updated;
- *Improved:* Disabled HW decoding by default;

## Version 4.0 - 2024/11/16
- *Fix:* Preload fix;
- *Fix:* Timeline fix;
- *Add:* Proper hardware decoding support (Linux only);
- *Add:* Shaders for displaying frames;
- *Add:* More signals;
- *Improved:* Improved README;
- *Improved:* Improved build script;
- *Improved:* Added caching;
- *Improved:* Performance in loading and displaying videos;
- *Improved:* Cleaned up header files;
- *Improved:* Test room got better with more controls and feedback;
- *Improved:* Smoother video loading for Windows;

## Version 3.2 - 2024/10/17
- *Fix:* 4K video playback;
- *Fix:* Multi-threading;
- *Fix:* Hardware decoding;
- *Fix:* Audio playback;
- *Fix:* Non smooth video playback;
- *Improved:* GitHub Workflow for test room;

## Version 3.1 - 2024/09/06
- *Fix:* Video playback for Windows;
- *Add:* More signals to video playback;
- *Add:* SWScale;
- *Improved:* Removed compute shaders due to incompatibility;
- *Improved:* Cleaned up FFmpeg builds;
- *Improved:* Workflow builds;

## Version 3.0 - 2024/08/30
- *Fix:* Memory leak;
- *Added:* YUV to RGB shader;
- *Added:* More debug symbols for debug builds;
- *Improved:* Addon scripts;
- *Improved:* Godot 4.3 is being used;
- *Improved:* Video class (c++);
- *Improved:* Project readme;
And some extra minor improvements.

## Version 2.2.2 - 2024/08/15
- *Fix:* `get_supported_codecs()` not working as expected;
- *Fix:* Memory leak for audio;
- *Add:* Static get meta data function;
- *Improved:* Removing unnecessary codecs;

## Version 2.2.1 - 2024/08/14
- *Fix:* Workflow builds (Didn't have any impact on users);

## Version 2.2 - 2024/08/12
- *Fix:* Small bug fix which made opening videos with audio enabled impossible;

## Version 2.1 - 2024/08/09
- *Add:* Proper error codes + error code documentation;
- *Add:* Build option for enabling GPL;
- *Add:* Option for H264 presets;
- *Add:* Option for not including Renderer class;
- *Add:* GitHub workflows;
- *Add:* Added option for smaller build size;
- *Add:* Added option for recompiling FFmpeg;

## Version 2.0 - 2024/08/02
### Fixes
- *Fix:* Multi threading not working;
- *Fix:* Compiling not working;
### Additions and Improvements
- *Add:* Rendering functionality included;
- *Add:* Quick builder;
- *Add:* More codec support;
- *Add:* More getters for the GDE;
- *Improved:* Builder;

## Version 1.0 - 2024/07/21
First version after the alpha. Everything should be working to display video's in Godot at this point.
- *Fix:* Windows not working;
- *Add:* Possibility to load video's without audio;
- *Improved:* Updated submodules;
- *Improved:* Build.py improvements;
