# GoZen_GDExtension

The core of GoZen which works thanks to FFmpeg!

## Under construction

This GDExtension still does not work (yet)!!

## Road-map

For the road map of this GDExtension we will keep it simple as we have a lot of it already working. There are only a couple of issues left to tackle to really make this GDExtension useful.

### TO-DO

- Getting all codecs to work properly;
- Interlacing/De-interlacing support;
- Audio needs to be fixed for some codecs;
- Not all frames can be taken from video files;
- Getting a correct number of all available video frames;
- Matching frames from video with length of audio;
- Add support for non-square pixel formats;

## Licensing

Please be careful and read up on the licensing of FFmpeg. If you want access to all video codecs and features, you'll have to use the GPL 3.0 license for your project. Licensing is complicated and I'm not a lawyer, we removed the --enable-gpl flag so the binaries are LGPL, but you can add that flag after '.configure' in the SCons file. Both us and FFmpeg can not be blamed for these licensing rules, blame the big (money hungry) companies with their (ridiculous) patents. 
> This software uses libraries from the FFmpeg project under the LGPLv2.1
