#!/bin/bash
set -e

LLVM_VERSION="17.0.6"
WORKSPACE_DIR=$(pwd)
LLVM_ARCHIVE="llvm-project-${LLVM_VERSION}.src.tar.xz"
LLVM_SRC="${WORKSPACE_DIR}/llvm-src"

curl -L "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_ARCHIVE}" -o "${LLVM_ARCHIVE}"

tar -xf "${LLVM_ARCHIVE}"
mv "llvm-project-${LLVM_VERSION}.src" "${LLVM_SRC}"
rm "${LLVM_ARCHIVE}"

HOST_BUILD="${WORKSPACE_DIR}/build-host"

cmake -S "${LLVM_SRC}/llvm" -B "${HOST_BUILD}"  -G Ninja \
  -Wno-dev \
  -Wno-deprecated \
  -DCMAKE_BUILD_TYPE=Release \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64"

cmake --build "${HOST_BUILD}" --target llvm-tblgen clang-tblgen --parallel "$(sysctl -n hw.ncpu)"

IOS_BUILD="${WORKSPACE_DIR}/build-ios"

cmake -S "${LLVM_SRC}/llvm"  -B "${IOS_BUILD}"  -G Ninja \
  -Wno-dev \
  -Wno-deprecated \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_C_FLAGS="-target arm64-apple-ios15.0 -w" \
  -DCMAKE_CXX_FLAGS="-target arm64-apple-ios15.0 -w" \
  -DCMAKE_OSX_SYSROOT="$(xcrun --sdk iphoneos --show-sdk-path)" \
  -DCMAKE_OSX_ARCHITECTURES="arm64" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="15.0" \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="arm64-apple-ios15.0" \
  -DLLVM_NATIVE_TOOL_DIR="${HOST_BUILD}/bin" \
  -DLLVM_ENABLE_ZSTD=OFF

cmake --build "${IOS_BUILD}" --parallel "$(sysctl -n hw.ncpu)"
