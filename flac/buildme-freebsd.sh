#!/bin/sh

OGG=1.3.5
FLAC=1.5.0
OGG_GIT=""
FLAC_GIT=""
LOG=$PWD/config.log
CHANGENO=$(git rev-parse --short HEAD)
OUTPUT=$PWD/flac-build-$ARCH-$CHANGENO

if [ -f "/etc/make.conf" ]; then
    CC=`grep CC /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CC=##g'`
    CXX=`grep CXX /etc/make.conf | grep -v CCACHE | grep -v \# | sed 's#CXX=##g'`
fi

if [ -z CC ]; then
    CC=cc
fi

if [ -z $CXX ]; then
    CXX=c++
fi


# Clean up
rm -rf $OUTPUT
rm -rf flac-$FLAC

## Start
echo "Most log mesages sent to $LOG... only 'errors' displayed here"
date > $LOG

# '-O2' reduces binary size with minimal performance loss.
export CFLAGS="-O2"
export CXXFLAGS="-O2"

## Build Ogg first
echo "Untarring libogg-$OGG.tar.gz..."
tar -xf libogg-${OGG}${OGG_GIT}.tar.?z
cd libogg-$OGG
echo "Configuring..."
CC=$CC CXX=$CXX ./configure --disable-shared >> $LOG
echo "Running make..."
gmake >> $LOG
cd ..

## Build
echo "Untarring..."
tar xf flac-${FLAC}${FLAC_GIT}.tar.?z >> $LOG
cd flac-$FLAC >> $LOG
patch -p1 < ../0001-Flac1.5.0-encoding_bytes_to_read.patch >> $LOG
patch -p1 < ../0002-Flac1.5.0-Force-use-of-C-locale.patch >> $LOG
mv configure.in configure.ac
autoreconf -fi
./autogen.sh
CC=$CC CXX=$CXX \
./configure --with-ogg-includes=$PWD/../libogg-$OGG/include --with-ogg-libraries=$PWD/../libogg-$OGG/src/.libs/ --disable-doxygen-docs --disable-oggtest --disable-shared --disable-xmms-plugin --disable-cpplibs --prefix $OUTPUT >> $LOG
echo "Running make"
gmake >> $LOG
echo "Running make install"
gmake install >> $LOG
cd ..

## Tar the whole package up
tar -zcvf $OUTPUT.tgz $OUTPUT
rm -rf $OUTPUT
rm -rf flac-$FLAC
rm -rf libogg-$OGG
