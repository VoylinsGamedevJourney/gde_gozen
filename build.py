import os
import sys
import platform as os_platform
import subprocess



def update_submodules():
    git_command = 'git submodule update' 

    print('\nInit/Update submodules:')
    print('1. No; (default)')
    print('2. Init;')
    print('3. Update.')

    match input('> '):
        case '2': subprocess.run(f'{git_command} --init --recursive', shell=True, cwd='./')
        case '3': subprocess.run(f'{git_command} --recursive --remote', shell=True, cwd='./')


def choose_platform():
    print('\nSelect platform:')
    print('1. Linux; (default)')
    print('2. Windows;')
    print('3. MacOS; (possibly working)')
    print('4. Android. (Not working)')

    match input('> '):
        case '2': return 'windows'
        case '3': return 'macos'
        case '4': return 'android'
        case _: return 'linux'


def choose_architecture(a_platform):
    # TODO: Make it possible to actually choose
    # This option will also need to be passed onto the ffmpeg build script
    return 'arm64' if a_platform == 'macos' else 'x86_64'


def choose_target():
    print('\nSelect target:')
    print('1. Debug; (default)')
    print('2. Release.')

    match input('> '):
        case '2': return 'release'
        case _: return 'debug dev_build=yes'


def compile_ffmpeg(a_platform):
    l_platform = 0

    if a_platform == 'linux': l_platform = 1
    elif a_platform == 'windows': l_platform = 2
    elif a_platform == 'macos': l_platform = 3
    elif a_platform == 'android': l_platform = 4

    print('\nDo you want to (re)compile ffmpeg?:')
    print('1. Yes; (default)')
    print('2. No.')

    match input('> '):
        case '2': return
    
    print('\nCompile FFmpeg with the GPL v3 license?: (Only needed for rendering)')
    print('1. No; (default)')
    print('2. Yes.')

    match input('> '):
        case '2':
            subprocess.run(f'./ffmpeg.sh {l_platform} 2', shell=True, cwd='./')
            subprocess.run('cp ./LICENSE.GPL3 ./test_room/addons/gde_gozen/', shell=True, cwd='./')
        case _: subprocess.run(f'./ffmpeg.sh {l_platform} 1', shell=True, cwd='./')


def check_wsl_installation():
    # Check if WSL is installend when running from Windows.
    try:
        l_result = subprocess.run('wsl --status', capture_output=True, text=True, shell=True)
        return l_result.returncode == 0
    except FileNotFoundError:
        return False


def check_required_programs_wsl():
    # Check if required programs are installed for WSL
    l_required_programs = {
        'gcc': 'build-essential',
        'make': 'build-essential',
        'pkg-config': 'pkg-config',
        'python3': 'python3',
        'scons': 'scons',
        'mingw-w64': 'mingw-w64',
        'git': 'git'
    }
    
    l_missing_programs = []
    
    for l_program, l_package in l_required_programs.items():
        l_result = subprocess.run(['wsl', 'which', l_program], 
                              capture_output=True, text=True, shell=True)
        if l_result.returncode != 0:
            l_missing_programs.append(l_package)
    
    return len(l_missing_programs) == 0, l_missing_programs


def print_install_wsl_instructions():
    # Providing instructions
    print('\n WSL (Windows Subsystem for Linux) is not installed!')
    print('\nSteps to install WSL:')
    print('\t1. Open PowerShell as an Administrator;')
    print('\t2. Run the command: wsl --install')
    print('\t3. Restart your computer;')
    print('\t4. Complete the Ubuntu setup when it launches automatically after restart;')
    print('\nAfter installation, run this script again.')
    input('\nPress Enter to exit...')
    sys.exit(1)


def install_wsl_required_programs():
    # Installing necessary WSL programs
    print('\nInstalling required programs in WSL')

    try:
        # Updating package list
        subprocess.run('wsl sudo apt-get update', shell=True, check=True)

        # Installing required packages
        subprocess.run(['wsl', 'sudo', 'apt-get', 'install', '-y',
                        'build-essential', 'pkg-config', 'python3',
                        'scons', 'mingw-w64', 'git'], shell=True)
        print('\nSuccessfully isntalled the required WSL programs!')
    except subprocess.CalledProcessError:
        print('\nError installing programs!')
        print('Please run the following commands in WSL manually:')
        print('\tsudo apt-get update')
        print('\tsudo apt-get install build-essential pkg-config python3 scons mingw-w64 git')
        input('Press Enter to exit...')
        sys.exit(1)


def windows_detected():
    print('\nWindows system detected ...')
    print('Need WSL to build GDE GoZen')

    if not check_wsl_installation():
        print_install_wsl_instructions()

    l_programs_installed, l_missing_programs = check_required_programs_wsl()

    if not l_programs_installed:
        print('\nSome required programs are missing in WSL:')

        for l_program in l_missing_programs:
            print(f'\t- {l_program}')

        # Attempt on installing them
        install_wsl_required_programs()

    try:
        # Navigate to the correct directory in WSL
        l_wsl_path = subprocess.run(['wsl', 'wslpath', os.getcwd()], 
                capture_output=True, text=True, shell=True).stdout.strip()
        
        # Run the build script
        subprocess.run(['wsl', 'python3', 'build.py'], 
                      cwd=l_wsl_path, check=True, shell=True)
        
        print("\nBuild completed successfully!")
    except subprocess.CalledProcessError as e:
        print(f"\nError during build process: {e}")
        input("\nPress Enter to exit...")
        sys.exit(1)

    sys.exit(0)


def main():
    print('v===================v')
    print('| GDE GoZen builder |')
    print('^===================^')
    
    if os_platform.system() == 'Windows':
        windows_detected()

    update_submodules()

    l_platform = choose_platform()
    l_arch = choose_architecture(l_platform)
    l_target = choose_target()
    l_threads = int(input('Number of threads/cores for compiling> '))

    compile_ffmpeg(l_platform)
    subprocess.run(f'scons -j{l_threads} target=template_{l_target} '
                   f'platform={l_platform} arch={l_arch}',
                   shell=True, cwd='./')

    print("\nDone building GDE GoZen!\n")


if __name__ == '__main__':
    main()
