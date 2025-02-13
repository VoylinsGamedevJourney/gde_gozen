import os
# This is a fix for the MacOS builds to get the libraries to properly connect to
# the gdextension library. Without it, the FFmpeg libraries can't be found.


debug_binary = 'test_room/addons/gde_gozen/bin/macos/debug/libgozen.macos.template_debug.dev.arm64.dylib'
release_binary = 'test_room/addons/gde_gozen/bin/macos/release/libgozen.macos.template_release.arm64.dylib'
debug_bin_folder = 'test_room/addons/gde_gozen/bin/macos/debug/bin'
release_bin_folder = 'test_room/addons/gde_gozen/bin/macos/release/bin'


def main():
    print("Updating @loader_path for MacOS builds")

    if os.path.exists(debug_binary):
        for file in os.listdir(debug_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {debug_binary}')

    if os.path.exists(release_binary):
        for file in os.listdir(release_bin_folder):
            os.system(f'install_name_tool -change ./bin/lib/{file} @loader_path/lib/{file} {release_binary}')


if __name__ == "__main__":
    main()
