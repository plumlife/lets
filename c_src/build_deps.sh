#!/bin/bash

# The MIT License
#
# Copyright (C) 2011-2015 by Joseph Wayne Norton <norton@alum.mit.edu>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

set -eo pipefail

CROSS="arm-plum-linux-gnueabi"

export PATH="/root/x-tools/arm-plum-linux-gnueabi/bin:${PATH}"
export CC="${CROSS}-gcc"
export CXX="${CROSS}-g++"
export AR="${CROSS}-ar"
export RANLIB="${CROSS}-ranlib"
export LD="${CROSS}-ld"
export LDD="${CROSS}-ldd"
export ELFEDIT="${CROSS}-elfedit"
export STRIP="${CROSS}-strip"

SNAPPY_VSN=1.0.4
LEVELDB_VSN=ARM32-1.18

if [ `basename $PWD` != "c_src" ]; then
    pushd c_src > /dev/null 2>&1
fi

mkdir -p $REBAR_DEPS_DIR

BASEDIR="$PWD"

case "$1" in
    clean)
        rm -f *.o ../priv/lib/*.so
        rm -rf snappy-$SNAPPY_VSN
        rm -rf leveldb leveldb-$LEVELDB_VSN
        ;;
    get_deps)
        echo $(pwd)
        tar xf snappy-$SNAPPY_VSN.tar.gz
        if [ -d "$REBAR_DEPS_DIR/leveldb" ];
        then
            echo "Already cloned and checked out"
        else
            cd $REBAR_DEPS_DIR && git clone git://github.com/plumlife/leveldb.git leveldb -b $LEVELDB_VSN --single-branch
        fi
        ;;
    update_deps)
        ;;
    *)
        LIBTOOLIZE=libtoolize
        ($LIBTOOLIZE --version) < /dev/null > /dev/null 2>&1 || {
            LIBTOOLIZE=glibtoolize
            ($LIBTOOLIZE --version) < /dev/null > /dev/null 2>&1 || {
                echo
                echo "You must have libtool (& friends) installed to compile LETS."
                echo
                exit -1
            }
        }

        # snappy
        if [ ! -f $BASEDIR/snappy/lib/libsnappy.a ]; then
            (cd snappy-$SNAPPY_VSN && \
                ./configure $CONFFLAGS \
                --host="${CROSS}"
                --with-pic \
                --prefix=$BASEDIR/snappy &&  \
                make install)
            rm -f $BASEDIR/snappy/lib/libsnappy.la
        fi
        
        export TARGET_OS="OS_LINUX_ARM_CROSSCOMPILE"
        
        # leveldb
        if [ ! -f $BASEDIR/leveldb/lib/libleveldb.a ]; then
            (cd $REBAR_DEPS_DIR/leveldb && git archive --format=tar --prefix=leveldb-$LEVELDB_VSN/ $LEVELDB_VSN) \
                | tar xf -
            (cd leveldb-$LEVELDB_VSN && \
                echo "echo \"PLATFORM_CFLAGS+=-fPIC -I$BASEDIR/snappy/include\" >> build_config.mk" >> build_detect_platform &&
                echo "echo \"PLATFORM_CXXFLAGS+=-fPIC -I$BASEDIR/snappy/include\" >> build_config.mk" >> build_detect_platform &&
                echo "echo \"PLATFORM_LDFLAGS+=-L $BASEDIR/snappy/lib -lsnappy\" >> build_config.mk" >> build_detect_platform &&
                make SNAPPY=1 && \
                mkdir -p $BASEDIR/leveldb/include/leveldb && \
                install include/leveldb/*.h $BASEDIR/leveldb/include/leveldb && \
                mkdir -p $BASEDIR/leveldb/lib && \
                install libleveldb.a $BASEDIR/leveldb/lib)
        fi
        ;;
esac
