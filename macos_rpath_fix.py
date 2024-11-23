import os
import sys
import subprocess


debug_binary = 'bin/macos/debug/libgozen.macos.template_debug.dev.arm64.dylib'
release_binary = 'bin/macos/release/libgozen.macos.template_release.arm64.dylib'


if os.path.exists(debug_binary):
    for file in os.listdir('bin/macos/debug/lib'):
        os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {debug_binary}')

if os.path.exists(release_binary):
    for file in os.listdir('bin/macos/release/lib'):
        os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {release_binary}')
