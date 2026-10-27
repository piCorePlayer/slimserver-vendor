#!/bin/sh

#pCP package Dependancies
tce-load -i git compiletc automake libtool gettext-dev openssl-dev

FLAC=1.5.0
SOX=14.4.3
OGG=1.3.5
OGG_GIT=""
FLAC_GIT=""
SOX_GIT="-0be259eaa9ce3f3fa587a3ef0cf2c0b9c73167a2"
VORBIS=1.3.7
OPUS=1.2.1
OPUSFILE=0.11
MAD=0.15.1b
MAD_SUB="-8"
WAVPACK=5.3.0
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH="pCP-$(uname -m)"
OUTPUT=$PWD/sox-build-$ARCH-$CHANGENO
CORES=$(grep -c ^processor /proc/cpuinfo)

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf opus-$OPUS
rm -rf opusfile-$OPUSFILE
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK

#armv6
case $(find /lib | grep ld-linux) in
  *armhf*)
    export CFLAGS="-O2 -pipe -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard"
    export CXXFLAGS="-O2 -pipe -fno-exceptions -fno-rtti -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp"
    BIT32="linux32"
  ;;
  *aarch64*)
    export CFLAGS="-O2 -pipe -march=armv8-a+crc -mtune=cortex-a72"
    export CXXFLAGS="-O2 -pipe -fno-exceptions -fno-rtti -march=armv8-a+crc -mtune=cortex-a72"
    BIT32=""
  ;;
esac



## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

## Build Ogg first
echo "Untarring libogg-$OGG.tar.gz..."
tar -xf libogg-${OGG}${OGG_GIT}.tar.?z
cd libogg-$OGG
#. ../../CPAN/update-config.sh
[ -x configure ] || ./autogen.sh >> $LOG
echo "Configuring..."
${BIT32} ./configure --disable-shared >> $LOG
echo "Running make..."
${BIT32} make -j $CORES >> $LOG
cd ..

## Build Vorbis
echo "Untarring libvorbis-$VORBIS.tar.gz..."
tar -xf libvorbis-$VORBIS.tar.?z
cd libvorbis-$VORBIS
#. ../../CPAN/update-config.sh
echo "Configuring..."
${BIT32} ./configure --with-ogg-includes=$PWD/../libogg-$OGG/include \
        --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs --disable-shared >> $LOG
echo "Running make"
${BIT32} make -j $CORES >> $LOG
cd ..

## Build Opus
echo "Untarring opus-$OPUS.tar.gz..."
tar -zxf opus-$OPUS.tar.?z
cd opus-$OPUS
echo "Configuring..."
${BIT32} ./configure --disable-extra-programs --enable-shared=no >> $LOG
echo "Running make"
${BIT32} make -j $CORES >> $LOG
cd ..

## Build Opusfile
echo "Untarring opusfile-$OPUSFILE.tar.gz..."
tar -xf opusfile-$OPUSFILE.tar.?z
cd opusfile-$OPUSFILE
echo "Configuring..."
CPF="-I$PWD/../libogg-$OGG/include -I$PWD/../opus-$OPUS/include"
LDF="-L$PWD/../libogg-$OGG/src/.libs -L$PWD/../opus-$OPUS/.libs"
${BIT32} ./configure DEPS_CFLAGS="$CPF" DEPS_LIBS="$LDF" --enable-shared=no --disable-examples --disable-doc >> $LOG
echo "Running make"
${BIT32} make -j $CORES >> $LOG
cd ..

## Build FLAC
#echo "Untarring flac-$FLAC.tar.gz..."
tar -xf flac-${FLAC}${FLAC_GIT}.tar.?z >> $LOG
cd flac-$FLAC
patch -p1 < ../01-flac.patch
#. ../../CPAN/update-config.sh
[ -x configure ] || ./autogen.sh >> $LOG
echo "Configuring..."
${BIT32} ./configure --with-ogg-includes=$PWD/../libogg-$OGG/include \
       --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-shared \
       --disable-cpplibs >> $LOG
echo "Running make"
${BIT32} make -j $CORES >> $LOG
cd ..

## Build LibMAD
echo "Untarring libmad-$MAD.tar.gz..."
tar -xf libmad-$MAD-8.tar.gz
cd libmad-$MAD
#. ../../CPAN/update-config.sh
# Remove -fforce-mem line as it doesn't work with newer gcc
sed -i 's/-fforce-mem//' configure
echo "configuring..."
${BIT32} ./configure --disable-shared >> $LOG
echo "Running make"
${BIT32} make -j $CORES >> $LOG
cd ..

## Build Wavpack
echo "Untarring wavpack-$WAVPACK.tar.bz2..."
tar -xf wavpack-$WAVPACK.tar.bz2
cd wavpack-$WAVPACK
#. ../../CPAN/update-config.sh
echo "Configuring..."
${BIT32} ./configure --disable-shared --with-iconv=no --disable-apps >> $LOG
echo "Running make"
${BIT32} make -j $CORES>> $LOG
# sox looks for wavpack/wavpack.h so we need to make a symlink
cd include
ln -s . wavpack
cd ../..

## finally, build SOX against FLAC
echo "Untarring sox-$SOX.tar.gz..."
tar -zxf sox-${SOX}${SOX_GIT}.tar.gz >> $LOG
cd sox-$SOX >> $LOG
#. ../../CPAN/update-config.sh
patch -p1 < ../02-restore-short-options.patch
patch -p1 < ../03-version.patch
patch -p0 < ../07-sox-missing-math.patch

#make libssp link statically
sudo rm /usr/local/lib/libssp*.so*

echo "Configuring..."
CPF="-I$PWD/../libogg-$OGG/include -I$PWD/../libvorbis-$VORBIS/include -I$PWD/../opus-$OPUS/include \
-I$PWD/../wavpack-$WAVPACK/include -I$PWD/../flac-$FLAC/include -I$PWD/../libmad-$MAD"
LDF="-L$PWD/../libogg-$OGG/src/.libs -L$PWD/../libvorbis-$VORBIS/lib/.libs -L$PWD/../opus-$OPUS/.libs \
-L$PWD/../wavpack-$WAVPACK/src/.libs -L$PWD/../libmad-$MAD/.libs -L$PWD/../flac-$FLAC/src/libFLAC/.libs"
${BIT32} ./configure CFLAGS="$CPF" LDFLAGS="$LDF" OPUS_CFLAGS="-I$PWD/../opusfile-$OPUSFILE/include" \
        OPUS_LIBS="-L$PWD/../opusfile-$OPUSFILE/.libs -lopusfile -lopus" --without-ao --without-pulseaudio \
        --disable-openmp --with-flac --with-oggvorbis --with-opus --with-mp3 --with-wavpack --without-id3tag \
        --without-lame --without-png --without-ladspa --disable-shared --without-oss --without-alsa \
        --disable-symlinks --without-coreaudio --prefix $OUTPUT --with-gnu-ld >> $LOG
echo "Running make"
${BIT32} make -j $CORES >> $LOG
echo "Running make install"
${BIT32} make install >> $LOG
cd ..

${BIT32} strip --strip-unneeded $OUTPUT/bin/*


## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf sox-$SOX
rm -rf opus-$OPUS
rm -rf opusfile-$OPUSFILE
rm -rf libogg-$OGG
rm -rf libvorbis-$VORBIS
rm -rf libmad-$MAD
rm -rf wavpack-$WAVPACK
