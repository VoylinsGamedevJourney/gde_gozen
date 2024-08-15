import subprocess

# NOTE: You will need to compile the editor with 'dlink_enabled=yes' to have GDExtension support in web builds

if __name__ == '__main__':
    print('GoZen GDExtension builder')
    print('Select platform:')
    print('1. Linux; (default)')
    print('2. Windows;')
    print('3. MacOS (WIP);')
    print('4. Android (WIP);')
    print('5. Web (WIP).')
    platform = 'linux'
    match input('> '):
        case '2': platform = 'windows'
        case '3': platform = 'macos'
        case '4': platform = 'android'
        case '5': platform = 'web'

    arch = 'x86_64'
    print('Select architexture:')
    if platform == 'linux':
        print('1. x86_64; (default)')
        print('2. arm64;')
        print('3. rv64.')
        match input('> '):
            case '2': arch = 'arm64'
            case '3': arch = 'rv64'
    elif platform == 'windows':
        print('1. x86_64; (default)')
        print('2. x86_32.')
        match input('> '):
            case '2': arch = 'x86_32'
    elif platform == 'macos':
        print('1. x86_64; (default)')
        print('2. arm64.')
        match input('> '):
            case '2': arch = 'arm64'
    elif platform == 'android':
        print('1. arm64;')
        print('2. arm32.')
        match input('> '):
            case '2': arch = 'arm32'
            case _: arch = 'arm64'

    target = 'debug'
    print('Select target:')
    print('1. Debug; (default)')
    print('2. Release.')
    match input('> '):
        case '2': target = 'release'

    extra_args = ''
    if target == 'debug':
        extra_args += ' dev_build=yes'

    use_system = False
    if platform == 'linux':
        print('Use system FFmpeg:')
        print('1. Yes; (default)')
        print('2. No.')
        match input('> '):
            case '2': extra_args += ' use_system=no'
            case _:
                extra_args += ' use_system=yes'
                use_system = True

    print('Include renderer:')
    print('1. no; (default)')
    print('2. Yes.')
    match input('> '):
        case '2': extra_args += ' include_renderer=yes'

    if not use_system:
        print('Recompile FFmpeg:')
        print('1. Yes; (default)')
        print('2. No.')
        match input('> '):
            case '2': extra_args += ' recompile_ffmpeg=no'

        print('Enable small: (takes longer to compile FFmpeg but libs are smaller)')
        print('1. No; (default)')
        print('2. Yes.')
        match input('> '):
            case '2': extra_args += ' enable_small=yes'

    user_input = input('Number of threads/cores for compiling> ')
    if user_input.isdigit():
        jobs = int(user_input)
    else:
        jobs = 1

    subprocess.run(f'scons -j{jobs} target=template_{target} platform={platform} arch={arch} {extra_args}', shell=True, cwd='./')
