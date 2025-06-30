# Changelog
All releases can be found on the [GDE GoZen repo release page](https://github.com/VoylinsGamedevJourney/gde_gozen/releases)


## [v7.0] - 2025/07/01
### Added
- Non-square pixel support;
- Automatic rotation;
- Android support;
- De-interlace video support;
- Correct playback with SAR smaller than 1.0;

### Fixed
- Fixed framerate;
- Editor FPS display fixed;
- GIF Playback now works correctly;
- GIF playback not showing correctly with certain resolutions;

### Improved
- Better handling of video file padding;
- Test room VSync turned off;


## [v6.2] - 2025/06/23
### Added
- AV1 playback support;
- GIF playback support;
- Container ogg support;

### Fixed
- MacOS compile fix;
- MacOS GDExtension usage fix;

### Improved
- Naming changed to not cause issues with other addons;
- Workflow switched to Ubuntu to give better support for older distro's;

### Deleted
- Hardware decoding;
- Removed MacOS x86_64 support (arm64 is sufficient);


## [v6.1.1] - 2025/05/10
### Fixed
- Audio test room;
- Exporting not copying libraries correctly;
- Web export not building;

### Improved
- Added line edit for URL/path in test room;
- Cleanup of main.gd;


## [v6.1] - 2025/05/10
### Added
- Feature request issue template;
- Globalize paths (res:// and user:// can now be used);
- Beginning for Web export;
- Clean scons option on build.py;

### Fixed
- Video not loading when path had been set;
- Videos with thumbnails not loading;
- `update_video` throwing error of texture size being wrong;
- Error when getting first frame;

### Improved
- FFmpeg library size;
- The whole repo got an update for the .md files;
- Improved `update_video` to accept audio;
- Smaller export size;
- Scons file;
- Workflow update;

### Removed
- `dev_build` from scons command;
- Error codes file;
- Compute shader;

## [v6.0] - 2025/04/21
### Added
- Added MacOS support;
- Added basics for Android support (Can't find anybody to test if it works or not);

### Fixed
- Compile on macos by @felixbaral in #38
- For missing libraries for Windows on export;
- Error for image dimension being bad;
- For older Python versions;
- Framerate mistake;
- For wrong color support;

### Improved
- Video load times;
- Implemented RAII for the GDExtension side of things;
- Updated Test room to Godot 4.4;
- Updated the test room itself with a load video button;
And some other code readability improvements with minor fixes ;)


## [v5.0] - 2025/03/09
Mac OS support is nearly complete, just some more testing which needs to be done. As we don't have any Mac OS testers at the moment there's a lack of knowing if things actually function correctly or not. The Mac OS stuff got implemented by following some updates of a PR from felixbaral so hopefully I didn't mess anything up.

Reason why I couldn't just merge that PR directly was because the build system had already changed too much compared to what the PR was based upon.

### Added
- Added playback speed control;
- Adding pitch adjust for speed control;
- Added an autoplay option;
- Added a loop option;
- Better performance for loading in Audio; (by removing seeking at beginning)
- Some performance improvements in video playback;
- Updated documentation;
- A better build script for compiling;
- Some renaming of functions and signal names;
- OS updates
- Added Linux ARM support;
- Possibility that Mac support is working; (We don't have any testers atm who can confirm if the Mac build works or not)

### Fixed
- Error of multiple signal binding;
- `video_ended` signal mistake;
- Build system for compiling on Windows; (with WSL)
- Removed Web support mentions from the project due to FFmpeg not being able to be compiled for web;
- Removed rendering; (this will be moved to another GDE due to the need not being high enough and the licensing becoming complicated to keep this in the main GDE GoZen)
- Removed EasyMenu for compiling as it wasn't up to date and the build.py script became good enough;
- Removed minimal Linux build; (needing to rely on people having the correct FFmpeg version installed isn't the best solution)


## [v4.1] - 2024/11/30
### Added
- Renderer class;
- Global errors;
- Enable audio toggle;
- GPL v3 build;
- Added an audio class to easily convert audio to WAV 16 bit;
- Added a separate FFmpeg class for handling some FFmpeg specific functions;
- Added Avio_audio to see data in memory as file;
- Added EasyMenu compile menu;
- Added SECURITY;
- Added CODE_OF_CONDUCT;
- Added CONTRIBUTING;
- Started adding code to compile for MacOS (Not working and not supported yet!!);

### Fixed
- Color range fix; (There was a problem with dark not being dark and light now being light)
- Fixed a couple of compile errors for Windows;
- HW decoding for Vulkan (Hardware decoding still has some overall issues which I'm working on);
- Problems on first startup with addon;

### Improved
- Compile info got a much needed update;
- Usage info also got a much needed update;
- Added the GPL v3 license for the GPL builds;
- Workflows got some extra additions;
- Build system got cleaned up;
- Python script build.py got updated;
- Disabled HW decoding by default;


## [v4.0] - 2024/11/16
### Added
- Proper hardware decoding support (Linux only);
- Shaders for displaying frames;
- More signals;

### Fixed
- Preload fix;
- Timeline fix;

### Improved
- Improved README;
- Improved build script;
- Added caching;
- Performance in loading and displaying videos;
- Cleaned up header files;
- Test room got better with more controls and feedback;
- Smoother video loading for Windows;


## [v3.2] - 2024/10/17
### Fixed
- 4K video playback;
- Multi-threading;
- Hardware decoding;
- Audio playback;
- Non smooth video playback;

### Improved
- GitHub Workflow for test room;


## [v3.1] - 2024/09/06
### Added
- More signals to video playback;
- SWScale;

### Fixed
- Video playback for Windows;

### Improved
- Removed compute shaders due to incompatibility;
- Cleaned up FFmpeg builds;
- Workflow builds;


## [v3.0] - 2024/08/30
### Added
- YUV to RGB shader;
- More debug symbols for debug builds;

### Fixed
- Memory leak;

### Improved
- Addon scripts;
- Godot 4.3 is being used;
- Video class (c++);
- Project readme;
And some extra minor improvements.


## [v2.2.2] - 2024/08/15
### Added
- Static get meta data function;

### Fixed
- `get_supported_codecs()` not working as expected;
- Memory leak for audio;

### Improved
- Removing unnecessary codecs;


## [v2.2.1] - 2024/08/14
### Fixed
- Workflow builds (Didn't have any impact on users);


## [v2.2] - 2024/08/12
### Fixed
- Small bug fix which made opening videos with audio enabled impossible;


## [v2.1] - 2024/08/09
### Added
- Proper error codes + error code documentation;
- Build option for enabling GPL;
- Option for H264 presets;
- Option for not including Renderer class;
- GitHub workflows;
- Added option for smaller build size;
- Added option for recompiling FFmpeg;


## [v2.0] - 2024/08/02
### Added
- Rendering functionality included;
- Quick builder;
- More codec support;
- More getters for the GDE;

### Fixed
- Multi threading not working;
- Compiling not working;

### Improved
- Builder;


## [v1.0] - 2024/07/21
First version after the alpha. Everything should be working to display video's in Godot at this point.

### Added
- Possibility to load video's without audio;

### Fixed
- Windows not working;

### Improved
- Updated submodules;
- Build.py improvements;
