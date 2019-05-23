#bin/bash

# tps nov. 2018
# Compile FFmpeg for Ubuntu, Debian, or Mint
# https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu

# sudo apt-get update -qq && sudo apt -y install \
#   autoconf \
#   automake \
#   build-essential \
#   cmake \
#   git-core \
#   libass-dev \
#   libfreetype6-dev \
#   libsdl2-dev \
#   libtool \
#   libva-dev \
#   libvdpau-dev \
#   libvorbis-dev \
#   libxcb1-dev \
#   libxcb-shm0-dev \
#   libxcb-xfixes0-dev \
#   pkg-config \
#   texinfo \
#   wget \
#   zlib1g-dev
#
# mkdir -p ~/ffmpeg_sources ~/bin
#
# sudo apt -y install yasm
#
# sudo apt -y install libx264-dev
#
# sudo apt -y install libfdk-aac-dev
#
# sudo apt -y install libmp3lame-devt420.netmaster.dk/current/home/tps/ffmpeg_sources/ffmpeg
#
# sudo apt -y install libzmq3-dev

# sudo apt -y install libtesseract-dev


# tps nov 2018. I get this error when I compile ffmpeg: "ERROR: libzmq not found using pkg-config"
# Edit and comment out line Libs.private: -lstdc++  -lsodium -lpgm -lpthread -lm -lnorm
# in file /usr/lib/x86_64-linux-gnu/pkgconfig/libzmq.pc
# If I run `pkg-config --debug libzmq` I get a hint that this line is invalid!
# `pkg-config --debug libzmq`:
# ...
# Unknown keyword 'Libs.private' in '/usr/lib/x86_64-linux-gnu/pkgconfig/libzmq.pc'
# ...

cd ~/ffmpeg_sources && \
# Use next two lines if you want to get ffmpeg code. For now, now need to get code!
#wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
#tar xjvf ffmpeg-snapshot.tar.bz2 && \
cd ffmpeg && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" \
./configure \
  --prefix="$HOME/ffmpeg_build" \
  --pkg-config-flags="--static" \
  --extra-cflags="-I$HOME/ffmpeg_build/include" \
  --extra-ldflags="-L$HOME/ffmpeg_build/lib" \
  --extra-libs="-lpthread -lm" \
  --bindir="$HOME/bin" \
  --enable-gpl \
  --enable-libass \
  --enable-libfdk-aac \
  --enable-libfreetype \
  --enable-libmp3lame \
  --enable-libvorbis \
  --enable-libx264 \
  --enable-libzmq \
  --disable-doc \
  --enable-libtesseract \
  --enable-nonfree && \
PATH="$HOME/bin:$PATH" make && \
PATH="$HOME/bin:$PATH" make tools/zmqsend && \
PATH="$HOME/bin:$PATH" make tools/ffescape && \
cp tools/zmqsend $HOME/bin
cp tools/ffescape $HOME/bin
make install && \
hash -r

# sudo apt -y install v4l-utils
# # Suspend on close lid
# sudo apt -y install pm-utils

# Når jeg inkluderer tesseract med --enable-libtesseract, så får jeg fejl
# når jeg compilerer ffmpeg med dette script:

# tps@t420:~/github/easystream$ ./compileFFmeg.sh 
# ERROR: tesseract not found using pkg-config

# If you think configure made a mistake, make sure you are using the latest
# version from Git.  If the latest version fails, report the problem to the
# ffmpeg-user@ffmpeg.org mailing list or IRC #ffmpeg on irc.freenode.net.
# Include the log file "ffbuild/config.log" produced by configure as this will help
# solve the problem.
# mkdir: cannot create directory ‘/usr/local/share/doc’: Permission denied
# make: *** [doc/Makefile:117: install-html] Error 1

# For at komme videre med tesseract, så forsøger jeg at compilere ffmpeg
# fra source-foler ~/ffmpeg_sources/ffmpeg med denne kommando:
# PS - make tager 15 min. umiddelbart efter `make clean`

./configure \
--prefix="$HOME/ffmpeg_build" \
--disable-doc \
--enable-libtesseract \     # for filter drawtext
--enable-libfreetype

# PS - make -j 4 tager 6 min. !!!

Jeg får:
mkdir: cannot create directory ‘/usr/local/share/ffmpeg’: Permission denied
Jeg prøver at tillægge 