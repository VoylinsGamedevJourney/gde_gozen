import subprocess
import readline

# NOTE: You will need to compile the editor with 'dlink_enabled=yes' to have GDExtension support in web builds

if __name__ == '__main__':
	print('GoZen GDExtension builder')
	print('Select platform:')
	print('1. Linux; (default)')
	print('2. Windows (WIP);')
	print('3. MacOS (WIP);')
	print('4. Android (WIP);')
	print('5. Web (WIP).')
	platform = 'linux'
	match input('> '):
		case '2': platform = 'windows'
		case '3': platform = 'macos'
		case '4': platform = 'android'
		case '5': platform = 'web'

	# arch = ''
	# if platform == 'linux':
	# 	print('Select architexture:')
	# 	print('1. x86_64;')
	# 	print('2. arm64;')
	# 	print('3. rv64.')
	# 	match input('> '):
	# 		case '1': arch = 'arch=x86_64'
	# 		case '2': arch = 'arch=arm64'
	# 		case '3': arch = 'arch=rv64'
	# elif platform == 'windows':
	# 	print('Select architexture:')
	# 	print('1. x86_64;')
	# 	print('2. x86_32.')
	# 	match input('> '):
	# 		case '1': arch = 'arch=x86_64'
	# 		case '2': arch = 'arch=x86_32'
	# elif platform == 'macos':
	# 	print('Select architexture:')
	# 	print('1. x86_64;')
	# 	print('2. arm64.')
	# 	match input('> '):
	# 		case '1': arch = 'arch=x86_64'
	# 		case '2': arch = 'arch=arm64'
	# elif platform == 'android':
	# 	print('Select architexture:')
	# 	print('1. arm64;')
	# 	print('2. arm32.')
	# 	match input('> '):
	# 		case '1': arch = 'arch=arm64'
	# 		case '2': arch = 'arch=arm32'

	target = 'debug'
	print('Select target:')
	print('1. Debug; (default)')
	print('2. Release.')
	match input('> '):
		case '2': target = 'release'

	user_input = input('Number of threads/cores for compiling> ')
	if user_input.isdigit():
		jobs = int(user_input)
	else:
		jobs = 1

	subprocess.run(f'scons -j{jobs} target=template_{target} platform={platform}', shell=True, cwd='./')
