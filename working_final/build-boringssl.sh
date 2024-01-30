#!/bin/bash

set -o errexit
set -o nounset
set -o pipefail

DEBIAN_FRONTEND=noninteractive apt-get install -y \
  bash \
  gcc \
  clang \
  make \
  automake \
  cmake \
  git g++ pkgconf libtool autoconf \
  coreutils

# improve compilation times
CORES=$(($(grep -c ^processor /proc/cpuinfo) - 1))

export MAKEFLAGS=-j${CORES}
export CTEST_BUILD_FLAGS=${MAKEFLAGS}
export HUNTER_JOBS_NUMBER=${CORES}
export HUNTER_USE_CACHE_SERVERS=true

# Build BoringSSL
git clone https://boringssl.googlesource.com/boringssl
cd boringssl
git checkout fips-20220613
cp "/openssl.ld" "/boringssl/openssl.ld"
mkdir build
cd /boringssl/build
cmake -DBUILD_SHARED_LIBS=1 -DCMAKE_SHARED_LINKER_FLAGS="-Wl,--version-script=/boringssl/openssl.ld" ..
make

# Make an .openssl directory for nginx and then symlink BoringSSL's include directory tree
mkdir -p "/boringssl/.openssl/lib"
cd "/boringssl/.openssl"
ln -s ../include include

# Copy the BoringSSL crypto libraries to .openssl/lib so nginx can find them
cd "/boringssl"
cp "build/crypto/libcrypto.so" ".openssl/lib"
cp "build/ssl/libssl.so" ".openssl/lib"

