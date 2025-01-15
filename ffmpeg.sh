#!/bin/bash
# This only works on Linux systems! (maybe WSL)


function configure_for_linux() {
	# Configuration for the lGPL version
	./configure --prefix=./bin --enable-shared \
		--arch=x86_64 --target-os=linux \
		--quiet --enable-pic \
		\
		--extra-cflags="-fPIC" --extra-ldflags="-fPIC" \
		\
		--disable-postproc --disable-avfilter --disable-sndio \
		--disable-doc --disable-programs --disable-ffprobe \
		--disable-htmlpages --disable-manpages --disable-podpages \
		--disable-txtpages --disable-ffplay --disable-ffmpeg
}


function configure_for_linux_gpl() {
	# Main difference is enabling GPL V3 and adding libx264 and libx265
	./configure --prefix=./bin --enable-shared \
		--enable-gpl --enable-version3 \
		--arch=x86_64 --target-os=linux \
		--quiet \
		--enable-pic \
		\
		--extra-cflags="-fPIC" --extra-ldflags="-fPIC" \
		\
		--disable-postproc --disable-avfilter --disable-sndio \
		--disable-doc --disable-programs --disable-ffprobe \
		--disable-htmlpages --disable-manpages --disable-podpages \
		--disable-txtpages --disable-ffplay --disable-ffmpeg \
		\
		--enable-libx264 --enable-libx265
}


function configure_for_windows() {
	# Configuration for the lGPL version
	./configure --prefix=./bin --enable-shared \
		--arch=x86_64 --target-os=mingw32 --enable-cross-compile \
		--cross-prefix=x86_64-w64-mingw32- \
		--quiet \
		--extra-libs=-lpthread  --extra-ldflags="-static"\
		--extra-cflags="-fPIC" --extra-ldflags="-fpic" \
		\
		--disable-postproc --disable-avfilter --disable-sndio \
		--disable-doc --disable-programs --disable-ffprobe \
		--disable-htmlpages --disable-manpages --disable-podpages \
		--disable-txtpages --disable-ffplay --disable-ffmpeg
}


function configure_for_windows_gpl() {
	# Main difference is enabling GPL V3 and adding libx264 and libx265
	./configure --prefix=./bin --enable-shared \
		--enable-gpl --enable-version3 \
		--arch=x86_64 --target-os=mingw32 --enable-cross-compile \
		--cross-prefix=x86_64-w64-mingw32- \
		--quiet \
		--extra-libs=-lpthread  --extra-ldflags="-static"\
		--extra-cflags="-fPIC" --extra-ldflags="-fpic" \
		\
		--disable-postproc --disable-avfilter --disable-sndio \
		--disable-doc --disable-programs --disable-ffprobe \
		--disable-htmlpages --disable-manpages --disable-podpages \
		--disable-txtpages --disable-ffplay --disable-ffmpeg \
		\
		--enable-libx264 --enable-libx265
}


function configure_for_macos() {
	# Configuration for the lGPL version
	./configure --prefix=./bin --enable-shared \
		--arch=arm64 --target-os=darwin --enable-cross-compile \
		--extra-ldflags="-mmacosx-version-min=10.13" \
		--quiet \
		--extra-cflags="-fPIC -mmacosx-version-min=10.13" \
		\
		--disable-postproc --disable-avfilter --disable-sndio \
		--disable-doc --disable-programs --disable-ffprobe \
		--disable-htmlpages --disable-manpages --disable-podpages \
		--disable-txtpages --disable-ffplay --disable-ffmpeg
}


# Showing option menu if needed
if [ $# -lt 1 ]; then
	echo "Please select an option:"
	echo "1: Compile for Linux; (Default)"
	echo "2: Compile for Windows;"
	echo "3: Compile for MacOS; (not working/maybe working)"
	echo "4: Compile for Web; (not working)"
	echo "5: Compile for Android; (not working)"
	echo "0: Clean FFmpeg;"

	read -p "Enter your choice: " choice
	echo ""
else
	choice=$1
fi

if [ "$choice" = '0' ]; then
	# Cleanup FFmpeg
	echo "Cleaning FFmpeg"

	make distclean
	rm -rf bin
	exit
fi


if [ $# -lt 2 ]; then
	echo "Compile with GPL: (Only needed for rendering videos)"
	echo "1: No; (Default)"
	echo "2: Yes;"

	read -p "Enter your choice: " gpl
	echo ""
else
	gpl=$2
fi

cd ffmpeg
case $choice in
	2) # Windows
		echo "Compiling FFmpeg for Windows ..."

		# Creating the folder if not existing
		if [ ! -d "./test_room/addons/gde_gozen/bin/windows" ]; then
			mkdir -p "./test_room/addons/gde_gozen/bin/windows"
		fi

		# Setting paths
		export PKG_CONFIG_LIBDIR="/usr/x86_64-w64-mingw32/lib/pkgconfig"
		export PKG_CONFIG_PATH="/usr/x86_64-w64-mingw32/lib/pkgconfig"
		PATH="/opt/bin:$PATH"

		# Configuring FFmpeg
		if [ "$gpl" = "2" ]; then
			configure_for_windows_gpl
		else
			configure_for_windows
		fi

		# Building FFmpeg
		make -j $(nproc)
		make install

		# Copying libraries to the correct path
		cp bin/bin/*.dll ../bin/windows
		cp /usr/x86_64-w64-mingw32/bin/libx26*.dll ../bin/windows
		;;
	3) # MacOS
		echo "Compiling FFmpeg for MacOS ..."

		# Creating the folder if not existing
		if [ ! -d "./test_room/addons/gde_gozen/bin/macos" ]; then
			mkdir -p "./test_room/addons/gde_gozen/bin/macos"
		fi

		# Configuring FFmpeg TODO: No GPL option yet
		configure_for_macos

		# Building FFmpeg
		make -j $(nproc)
		make install

		# Copying libraries to the correct path
		cp bin/bin/*.dll ../bin/windows
		cp /usr/x86_64-w64-mingw32/bin/libx26*.dll ../bin/windows
		;;
	4)
		echo "Compiling for Web not supported yet!"
		;;
	5)
		echo "Compiling for Android not supported yet!"
		;;
	*) # Linux
		echo "Compiling FFmpeg for Linux ..."

		# Creating the folder if not existing
		if [ ! -d "./test_room/addons/gde_gozen/bin/linux" ]; then
			mkdir -p "./test_room/addons/gde_gozen/bin/linux"
		fi

		# Setting paths
		export PKG_CONFIG_PATH=/usr/lib/pkgconfig

		# Configuring FFmpeg
		if [ "$gpl" = "2" ]; then
			configure_for_linux_gpl
		else
			configure_for_linux
		fi

		# Building
		make -j $(nproc)
		make install

		# Copying libraries to the correct path
		cp bin/lib/*.so* ../bin/linux
		cp /usr/lib/libx26*.so ../bin/linux
		;;
esac

echo "FFmpeg.sh finished!"
echo ""

