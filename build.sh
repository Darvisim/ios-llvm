# Script from [holzschu](https://gist.github.com/holzschu/9aa539ba7f44b5ea0c18dccdfd85b212)
#! /bin/bash

curl http://releases.llvm.org/6.0.0/llvm-6.0.0.src.tar.xz -O
tar xvzf llvm-6.0.0.src.tar.xz
rm llvm-6.0.0.src.tar.xz
cd llvm-6.0.0.src

# get clang
pushd tools
curl http://releases.llvm.org/6.0.0/cfe-6.0.0.src.tar.xz -O
tar xvzf http://releases.llvm.org/6.0.0/cfe-6.0.0.src.tar.xz
rm http://releases.llvm.org/6.0.0/cfe-6.0.0.src.tar.xz
mv cfe-6.0.0.src clang
popd

# Get libcxx and libcxxabi
pushd projects
curl http://releases.llvm.org/6.0.0/libcxx-6.0.0.src.tar.xz -O
tar xvzf libcxx-6.0.0.src.tar.xz
rm libcxx-6.0.0.src.tar.xz
mv libcxx-6.0.0.src libcxx
curl http://releases.llvm.org/6.0.0/libcxxabi-6.0.0.src.tar.xz -O
tar xvzf libcxxabi-6.0.0.src.tar.xz
rm libcxxabi-6.0.0.src.tar.xz
mv libcxxabi-6.0.0.src libcxxabi
popd

# compile for OSX (about 2h, 8GB of disk space with BUILD_SHARED_LIBS=ON)
mkdir -f build_osx
pushd build_osx
cmake -DBUILD_SHARED_LIBS=ON  ..
cmake --build .
popd

# get libcxx and libcxxabi out of the way:
mkdir -f dontBuild
mv projects/libcxx dontBuild
mv projects/libcxxabi dontBuild
# TODO: some combination of build variables might allow us to build these too.
# Right now, they fail. Maybe CFLAGS with: -D__need_size_t -D_LIBCPP_STRING_H_HAS_CONST_OVERLOADS

# Now, compile for iOS using the previous build:
# About 24h, 6 GB of disk space
# Flags you could use: LLVM_LINK_LLVM_DYLIB and BUILD_SHARED_LIBS, to make everything use dynamic libraries
# (I did not test these)
LLVM_SRC = ${PWD}
mkdir -f build_ios
pushd build_ios
cmake -DBUILD_SHARED_LIBS=ON -DLLVM_TARGET_ARCH=AArch64 \
-DLLVM_TARGETS_TO_BUILD=AArch64 \
-DLLVM_DEFAULT_TARGET_TRIPLE=arm64-apple-darwin17.5.0 \
-DLLVM_ENABLE_THREADS=OFF \
-DLLVM_TABLEGEN=${LLVM_SRC}/build_osx/bin/llvm-tblgen \
-DCLANG_TABLEGEN=${LLVM_SRC}/build_osx/bin/clang-tblgen \
-DCMAKE_OSX_SYSROOT=/Applications/Xcode.app/Contents/Developer/Platforms/iPhoneOS.platform/Developer/SDKs/iPhoneOS.sdk/ \
-DCMAKE_C_COMPILER=${LLVM_SRC}/build_osx/bin/clang \
-DCMAKE_LIBRARY_PATH=${LLVM_SRC}/build_osx/lib/ \
-DCMAKE_INCLUDE_PATH=${LLVM_SRC}/build_osx/include/ \
-DCMAKE_C_FLAGS="-arch arm64 -target arm64-apple-darwin17.5.0 -I${LLVM_SRC}/build_osx/include/ -miphoneos-version-min=11" \
-DCMAKE_CXX_FLAGS="-arch arm64 -target arm64-apple-darwin17.5.0 -I${LLVM_SRC}/build_osx/include/c++/v1/ -miphoneos-version-min=11" \
..
cmake --build .
popd

