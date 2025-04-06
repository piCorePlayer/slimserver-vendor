
#!/bin/sh

#pCP package Dependancies
tce-load -i git compiletc automake gettext-dev

OGG=1.3.5
FLAC=1.5.0
OGG_GIT=""
FLAC_GIT=""
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
ARCH=`uname -m`
ARCH="pCP-$ARCH"
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO
CORES=$(grep -c ^processor /proc/cpuinfo)

# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

case $(find /lib | grep ld-linux) in
    *armhf*)
       export CFLAGS="-O2 -pipe -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp -mfloat-abi=hard"
       export CXXFLAGS="-O2 -pipe -fno-exceptions -fno-rtti -march=armv6zk -mtune=arm1176jzf-s -mfpu=vfp"
       BIT32="linux32"
    ;;
    *aarch64*)
       export CFLAGS="-Os -pipe -march=armv8-a+crc -mtune=cortex-a72"
       export CXXFLAGS="-Os -pipe -fno-exceptions -fno-rtti -march=armv8-a+crc -mtune=cortex-a72"
       BIT32=""
    ;;
esac


## Build Ogg first
echo "Untarring libogg-$OGG.tar.gz..."
tar -Jxf libogg-${OGG}${OGG_GIT}.tar.xz
cd libogg-$OGG
. ../../CPAN/update-config.sh
echo "Configuring..."
${BIT32} ./configure --disable-shared >> $LOG
echo "Running make..."
${BIT32} make -j $CORES >> $LOG
cd ..

## Build
echo "Untarring...flac-$FLAC"
tar Jxvf flac-${FLAC}${FLAC_GIT}.tar.xz >> $LOG
cd flac-$FLAC >> $LOG
patch -p1 < ../0001-Flac1.5.0-encoding_bytes_to_read.patch >> $LOG
patch -p1 < ../0002-Flac1.5.0-Force-use-of-C-locale.patch >> $LOG
. ../../CPAN/update-config.sh
echo "Configuring..."
${BIT32} ./configure --with-ogg-includes=$PWD/../libogg-$OGG/include \
--with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs \
--disable-shared --disable-xmms-plugin --disable-cpplibs --prefix $OUTPUT >> $LOG
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
rm -rf libogg-$OGG
