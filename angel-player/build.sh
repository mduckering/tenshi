#!/bin/bash -xe

# Licensed to Pioneers in Engineering under one
# or more contributor license agreements.  See the NOTICE file
# distributed with this work for additional information
# regarding copyright ownership.  Pioneers in Engineering licenses
# this file to you under the Apache License, Version 2.0 (the
# "License"); you may not use this file except in compliance
#  with the License.  You may obtain a copy of the License at
#
#    http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the License is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
# KIND, either express or implied.  See the License for the
# specific language governing permissions and limitations
# under the License

ANGEL_PLAYER_MAIN_DIR=$PROJECT_ROOT_DIR/angel-player

# TODO(kzentner): Fix this hack?
VENDOR_JS=$PROJECT_ROOT_DIR/angel-player/src/chrome/content/vendor-js/
cp $PROJECT_ROOT_DIR/build/vm/release_emscripten/vm/angelic/src/ngl_vm.js $VENDOR_JS
cp $PROJECT_ROOT_DIR/build/lua/release_emscripten/vm/lua/lua.js $VENDOR_JS
cp $PROJECT_ROOT_DIR/build/network/release_emscripten/network/ndl3.js $VENDOR_JS

mkdir -p $PROJECT_ROOT_DIR/build/angel-player
pushd $PROJECT_ROOT_DIR/build/angel-player

# Download XULRunner if it isn't already
if [ ! -e xulrunner-30.0.en-US.linux-x86_64.tar.bz2 ]
then
    if [ -e ~/tenshi-cache/xulrunner-30.0.en-US.linux-x86_64.tar.bz2 ]
    then
        cp ~/tenshi-cache/xulrunner-30.0.en-US.linux-x86_64.tar.bz2 .
    else
        wget http://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/30.0/runtimes/xulrunner-30.0.en-US.linux-x86_64.tar.bz2
    fi
fi
if [ ! -e xulrunner-30.0.en-US.win32.zip ]
then
    if [ -e ~/tenshi-cache/xulrunner-30.0.en-US.win32.zip ]
    then
        cp ~/tenshi-cache/xulrunner-30.0.en-US.win32.zip .
    else
        wget http://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/30.0/runtimes/xulrunner-30.0.en-US.win32.zip
    fi
fi
if [ ! -e xulrunner-30.0.en-US.mac.tar.bz2 ]
then
    if [ -e ~/tenshi-cache/xulrunner-30.0.en-US.mac.tar.bz2 ]
    then
        cp ~/tenshi-cache/xulrunner-30.0.en-US.mac.tar.bz2 .
    else
        wget http://ftp.mozilla.org/pub/mozilla.org/xulrunner/releases/30.0/runtimes/xulrunner-30.0.en-US.mac.tar.bz2
    fi
fi

# Check if any changes were made to the code
find -L $ANGEL_PLAYER_MAIN_DIR/src -type f -exec md5sum {} \; > new-src-hash
find -L $ANGEL_PLAYER_MAIN_DIR/meta-mac -type f -exec md5sum {} \; >> new-src-hash

if [ ! -e src-hash ]
then
    should_rearchive=1
else
    # We need to use diff rather than md5sum -c or similar in order to find
    # new/deleted files
    set +e
    diff -a new-src-hash src-hash >/dev/null
    if [ $? -eq 0 ]
    then
        # No difference
        should_rearchive=0
    elif [ $? -eq 1 ]
    then
        # Difference
        should_rearchive=1
    else
        echo "Diff failed!"
        exit $?
    fi
    set -e
fi

if [ $should_rearchive -eq 0 ]
then
    echo "Skipping build due to no files changed..."
    exit 0
fi

# Prepare Mac/Linux/Windows version. Use an awful hack to combine them.
rm -rf angel-player.app
mkdir angel-player.app
pushd angel-player.app
unzip ../xulrunner-30.0.en-US.win32.zip
mv xulrunner xul-win32
tar xjf ../xulrunner-30.0.en-US.linux-x86_64.tar.bz2
mv xulrunner xul-lin64
cp xul-lin64/xulrunner-stub angel-player
cp xul-win32/xulrunner-stub.exe angel-player.exe
# This is a god-awful hack to change the XULrunner directory. This essentially
# patches line 261 of nsXULStub.cpp
sed -i 's/%sxulrunner/%sxul-lin64/g' angel-player
sed -i 's/%sxulrunner/%sxul-win32/g' angel-player.exe
# Copy in angel-player code
cp -r --dereference $ANGEL_PLAYER_MAIN_DIR/src/* .
# Remove debug file
rm defaults/preferences/debug.js
# Do Mac stuff
# Mac OS requires a bunch of random futzing with stuff, but it's all in its
# own directory.
mkdir -p Contents/Frameworks
pushd Contents/Frameworks
tar xjf ../../../xulrunner-30.0.en-US.mac.tar.bz2
popd
# Symlink the source code. Breaks on Windows. Whatever.
ln -s .. Contents/Resources
# Random plists and stub and things.
cp -r $ANGEL_PLAYER_MAIN_DIR/meta-mac/* Contents
popd

$PROJECT_ROOT_DIR/tools/inject-version-angel-player.py $ANGEL_PLAYER_MAIN_DIR/src/application.ini angel-player.app/application.ini

# Archive the output
tar cjf ../artifacts/angel-player.tar.bz2 angel-player.app

cp new-src-hash src-hash

popd
