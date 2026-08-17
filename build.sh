#!/bin/bash
set -e

LLVM_VERSION="22.1.8"
WORKSPACE_DIR=$(pwd)
LLVM_ARCHIVE="llvm-project-${LLVM_VERSION}.src.tar.xz"
LLVM_SRC="${WORKSPACE_DIR}/llvm-src"

echo "Fetching and extracting LLVM ${LLVM_VERSION} source code"
curl -L "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_ARCHIVE}" -o "${LLVM_ARCHIVE}"

tar -xf "${LLVM_ARCHIVE}"
mv "llvm-project-${LLVM_VERSION}.src" "${LLVM_SRC}"
rm "${LLVM_ARCHIVE}"

echo "Applying LLVM CMake Patches for iOS"
ADDLLVM="${LLVM_SRC}/llvm/cmake/modules/AddLLVM.cmake"
perl -0pi -e 's/if\(NOT LLVM_NO_DEAD_STRIP\)\n\s+if\("\$\{CMAKE_SYSTEM_NAME\}" MATCHES "Darwin"\)/if(NOT LLVM_NO_DEAD_STRIP)\n      if("\${CMAKE_SYSTEM_NAME}" MATCHES "Darwin|iOS")/' "${ADDLLVM}"
HANDLELLVMOPTIONS="${LLVM_SRC}/llvm/cmake/modules/HandleLLVMOptions.cmake"
perl -0pi -e 's/CMAKE_SYSTEM_NAME MATCHES "Darwin\|FreeBSD/CMAKE_SYSTEM_NAME MATCHES "Darwin|iOS|FreeBSD/' "${HANDLELLVMOPTIONS}"

echo "Building host TableGen utils"
HOST_BUILD="${WORKSPACE_DIR}/build-host"

cmake -S "${LLVM_SRC}/llvm" -B "${HOST_BUILD}"  -G Ninja \
  -Wno-author \
  -Wno-deprecated \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64"

cmake --build "${HOST_BUILD}" --target llvm-tblgen clang-tblgen --parallel "$(sysctl -n hw.ncpu)"

echo "Building iOS ARM64 target"
IOS_BUILD="${WORKSPACE_DIR}/build-ios"

cmake -S "${LLVM_SRC}/llvm" -B "${IOS_BUILD}" -G Ninja \
  -Wno-author \
  -Wno-deprecated \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_C_FLAGS="-w" \
  -DCMAKE_CXX_FLAGS="-w" \
  -DCMAKE_MACOSX_BUNDLE=OFF \
  -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)" \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="15.0" \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="arm64-apple-ios15.0" \
  -DLLVM_NATIVE_TOOL_DIR="${HOST_BUILD}/bin"

cmake --build "${IOS_BUILD}" --parallel "$(sysctl -n hw.ncpu)"

echo "Building iOS ARM64 simulator target"
IOS_SIMULATOR_BUILD="${WORKSPACE_DIR}/build-ios-simulator"

cmake -S "${LLVM_SRC}/llvm" -B "${IOS_SIMULATOR_BUILD}" -G Ninja \
  -Wno-author \
  -Wno-deprecated \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_C_FLAGS="-w" \
  -DCMAKE_CXX_FLAGS="-w" \
  -DCMAKE_MACOSX_BUNDLE=OFF \
  -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphonesimulator --show-sdk-path)" \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="15.0" \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="arm64-apple-ios15.0-simulator" \
  -DLLVM_NATIVE_TOOL_DIR="${HOST_BUILD}/bin"
  
cmake --build "${IOS_SIMULATOR_BUILD}" --parallel "$(sysctl -n hw.ncpu)"
