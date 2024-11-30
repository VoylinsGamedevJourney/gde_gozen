import subprocess

# NOTE: You will need to compile the editor with '' to have GDExtension support in web builds

# Command for quick-building test:
# scons -j10 target=template_debug dev_build=yes platform=linux arch=x86_64 location=test_room/addons/gde_gozen/bin use_system=no recompile_ffmpeg=no

if __name__ == '__main__':
    platform = 'linux'
    arch = 'x86_64'
    target = 'debug'
    extra_args = ''
    use_system = False
    gpl = ''

    print('GoZen GDExtension builder\n'
          'Select platform:\n'
          '1. Linux; (default)\n'
          '2. Windows;\n'
          '3. MacOS; (Not working)\n'
          '4. Web; (Not working)\n'
          '4. Android; (Not working)')

    match input('> '):
        case '2': platform = 'windows'
        case '3': platform = 'macos'
        case '4': platform = 'web dlink_enabled=yes'
        case '5': platform = 'android'

    print('Select target:\n'
          '1. Debug; (default):\n'
          '2. Release.')

    match input('> '):
        case '2': target = 'release'
        case _: extra_args += ' dev_build=yes'

    if platform == 'linux':
        print('Use system FFmpeg:\n'
              '1. No; (default)\n'
              '2. Yes.')

        match input('> '):
            case '2':
                extra_args += ' use_system=yes'
                use_system = True
            case _: extra_args += ' use_system=no'

    if not use_system:
        print('Recompile FFmpeg:\n',
              '1. Yes; (default)\n',
              '2. No.')

        match input('> '):
            case '2': extra_args += ' recompile_ffmpeg=no'
            case _:
                extra_args += ' recompile_ffmpeg=yes'

                print('Use GPL3:\n'
                      '1. No; (default)\n'
                      '2. Yes.')

                match input('> '):
                    case '2': extra_args += ' enable_gpl=yes'
                    case _: extra_args += ' enable_gpl=no'

    user_input = input('Number of threads/cores for compiling> ')
    if user_input.isdigit():
        jobs = int(user_input)
    else:
        jobs = 1

    print('Select location:\n'
          '1. Bin; (default)\n'
          '2. Test room.')

    match input('> '):
        case '2': extra_args += ' location=test_room/addons/gde_gozen/bin'
        case _: extra_args += ' location=bin'

    subprocess.run(f'scons -j{jobs} target=template_{target} '
                   'platform={platform} arch={arch} {extra_args}',
                   shell=True, cwd='./')
