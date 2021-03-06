#!/bin/bash

# Copyright 2017 The CodeWorld Authors. All rights reserved.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

source base.sh

rm -rf $BUILD ~/.ghc ~/.ghcjs

mkdir $BUILD
mkdir $BUILD/downloads
mkdir $BUILD/bin

# Determine which package management tool is installed, and install
# necessary system packages.

if type yum > /dev/null 2> /dev/null
then
  echo Detected 'yum': Installing packages from there.
  echo

  # Update and install basic dependencies

  run . sudo yum update -y

  run . sudo yum install -y git
  run . sudo yum install -y wget
  run . sudo yum install -y bzip2
  run . sudo yum install -y zlib-devel
  run . sudo yum install -y ncurses-devel

  # Needed for GHC 7.8
  run . sudo yum install -y gcc
  run . sudo yum install -y gcc-c++
  run . sudo yum install -y gmp-devel

  # Needed for GHCJS
  run . curl --silent --location https://rpm.nodesource.com/setup_7.x | run . sudo bash -
  run . sudo yum install -y nodejs

  # Needed for ghcjs-boot --dev
  run . sudo yum install -y patch
  run . sudo yum install -y autoconf
  run . sudo yum install -y automake
elif type apt-get > /dev/null 2> /dev/null
then
  echo Detected 'apt-get': Installing packages from there.
  echo

  # Update and install basic dependencies

  run . sudo apt-get update -y

  run . sudo apt-get install -y git
  run . sudo apt-get install -y wget
  run . sudo apt-get install -y bzip2
  run . sudo apt-get install -y xz-utils
  run . sudo apt-get install -y psmisc

  run . sudo apt-get install -y zlib1g-dev
  run . sudo apt-get install -y libncurses5-dev

  # Needed for GHC 7.8
  run . sudo apt-get install -y make
  run . sudo apt-get install -y gcc
  run . sudo apt-get install -y g++
  run . sudo apt-get install -y libgmp-dev

  # Needed for GHCJS
  run . curl -sL https://deb.nodesource.com/setup_7.x | run . sudo -E bash -
  run . sudo apt-get install -y nodejs

  # Needed for ghcjs-boot --dev
  run . sudo apt-get install -y patch
  run . sudo apt-get install -y autoconf
  run . sudo apt-get install -y automake
  run . sudo apt-get install -y libtinfo-dev
elif type zypper > /dev/null 2> /dev/null
then
  echo Detected 'zypper': Installing packages from there.
  echo

  # Update and install basic dependencies

  run . sudo zypper -n refresh

  run . sudo zypper -n install git
  run . sudo zypper -n install wget
  run . sudo zypper -n install bzip2
  run . sudo zypper -n install psmisc

  run . sudo zypper -n install zlib-devel
  run . sudo zypper -n install ncurses-devel

  # Needed for GHC 7.8
  run . sudo zypper -n install make
  run . sudo zypper -n install gcc
  run . sudo zypper -n install gmp-devel

  # Needed for GHCJS
  run . sudo zypper -n install nodejs6

  # Needed for ghcjs-boot --dev
  run . sudo zypper -n install patch
  run . sudo zypper -n install autoconf
  run . sudo zypper -n install automake
else
  echo "WARNING: Could not find package manager."
  echo "Make sure necessary packages are installed."
fi

# Choose the right GHC download
if /sbin/ldconfig -p | grep -q libgmp.so.10; then
  GHC_ARCH=`uname -m`-deb8-linux
elif /sbin/ldconfig -p | grep -q libgmp.so.3; then
  GHC_ARCH=`uname -m`-centos67-linux
else
  echo Sorry, but no supported libgmp is installed.
  exit 1
fi

# Install a precompiled GHC to bootstrap itself.

GHC_DIR=8.0.2
GHC_VERSION=8.0.2

run $DOWNLOADS               wget http://downloads.haskell.org/~ghc/$GHC_DIR/ghc-$GHC_VERSION-$GHC_ARCH.tar.xz
run $BUILD                   tar xf $DOWNLOADS/ghc-$GHC_VERSION-$GHC_ARCH.tar.xz
run $BUILD/ghc-$GHC_VERSION  ./configure --prefix=$BUILD
run $BUILD/ghc-$GHC_VERSION  make install
run $BUILD                   rm -rf ghc-$GHC_VERSION

# Now install the patched GHC, built from source.

run $DOWNLOADS               wget https://downloads.haskell.org/~ghc/$GHC_DIR/ghc-$GHC_VERSION-src.tar.xz
run $BUILD                   tar xf $DOWNLOADS/ghc-$GHC_VERSION-src.tar.xz
run .                        patch -p0 -u -d $BUILD < ghc-artifacts/ghc-$GHC_VERSION-default-main.patch
run .                        cp ghc-artifacts/build.mk $BUILD/ghc-$GHC_VERSION/mk/build.mk
run $BUILD/ghc-$GHC_VERSION  ./configure --prefix=$BUILD
run $BUILD/ghc-$GHC_VERSION  make
run $BUILD/ghc-$GHC_VERSION  make install
run $BUILD                   rm -rf ghc-$GHC_VERSION

# Install all the dependencies for cabal

run $DOWNLOADS                     wget https://www.haskell.org/cabal/release/cabal-install-2.0.0.0/cabal-install-2.0.0.0.tar.gz
run $BUILD                         tar xf $DOWNLOADS/cabal-install-2.0.0.0.tar.gz
EXTRA_CONFIGURE_OPTS="" run $BUILD/cabal-install-2.0.0.0 ./bootstrap.sh
run .                              cabal update
run $BUILD                         rm -rf cabal-install-2.0.0.0

# Fetch the prerequisites for GHCJS.

run .  cabal_install happy alex

# Install GHCJS itself (https://github.com/ghcjs/ghcjs) and cabal install.

run $BUILD  git clone --branch ghc-8.0 --single-branch https://github.com/ghcjs/ghcjs
run $BUILD  cabal_install ./ghcjs
run $BUILD  rm -rf ghcjs
run . ghcjs-boot --dev --ghcjs-boot-dev-branch ghc-8.0 --shims-dev-branch ghc-8.0 --no-prof --no-haddock

run $BUILD  rm -rf downloads

# Install and build CodeMirror editor.

run $BUILD            git clone https://github.com/codemirror/CodeMirror.git
run $BUILD/CodeMirror git checkout tags/5.25.2
run $BUILD/CodeMirror npm install
run $BUILD/CodeMirror npm install -s uglify-js

function build_codemirror {
  bin/compress codemirror haskell active-line dialog matchbrackets \
    placeholder rulers runmode search searchcursor show-hint \
    --local node_modules/uglify-js/bin/uglifyjs \
    > codemirror-compressed.js
}

run $BUILD/CodeMirror build_codemirror

# Go ahead and run a first build, which installs more local packages.
./build.sh
