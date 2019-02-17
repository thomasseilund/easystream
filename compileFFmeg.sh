#bin/bash

# tps nov. 2018
# Compile FFmpeg for Ubuntu, Debian, or Mint
# https://trac.ffmpeg.org/wiki/CompilationGuide/Ubuntu

sudo apt-get update -qq && sudo apt-get -y install \
  autoconf \
  automake \
  build-essential \
  cmake \
  git-core \
  libass-dev \
  libfreetype6-dev \
  libsdl2-dev \
  libtool \
  libva-dev \
  libvdpau-dev \
  libvorbis-dev \
  libxcb1-dev \
  libxcb-shm0-dev \
  libxcb-xfixes0-dev \
  pkg-config \
  texinfo \
  wget \
  zlib1g-dev

mkdir -p ~/ffmpeg_sources ~/bin

sudo apt-get install yasm

sudo apt-get install libx264-dev

sudo apt-get install libfdk-aac-dev

sudo apt-get install libmp3lame-dev

sudo apt install libzmq3-dev

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
wget -O ffmpeg-snapshot.tar.bz2 https://ffmpeg.org/releases/ffmpeg-snapshot.tar.bz2 && \
tar xjvf ffmpeg-snapshot.tar.bz2 && \
cd ffmpeg && \
PATH="$HOME/bin:$PATH" PKG_CONFIG_PATH="$HOME/ffmpeg_build/lib/pkgconfig" ./configure \
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
  --enable-nonfree && \
PATH="$HOME/bin:$PATH" make && \
PATH="$HOME/bin:$PATH" make tools/zmqsend && \
cp tools/zmqsend $HOME/bin
make install && \
hash -r

sudo apt install v4l-utils
# Suspend on close lid
sudo apt install pm-utils
