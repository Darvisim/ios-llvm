#!/bin/bash
set -e

TARGET="${1:-}"
BUILD_TYPE="${2:-Release}"

if [[ -z "${TARGET}" ]]; then
    echo "Usage: $0 <target> [build-type]"
    echo "Targets:"
    echo "  ios-arm64"
    echo "  ios-simulator-arm64"
    echo "  ios-simulator-x86_64"
    exit 1
fi

case "${BUILD_TYPE}" in
    Release|Debug)
        ;;
    *)
        echo "Unknown build type: ${BUILD_TYPE}"
        echo "Build types: Release, Debug"
        exit 1
        ;;
esac

case "${TARGET}" in
    ios-arm64)
        SDK="iphoneos"
        ARCH="arm64"
        TRIPLE="arm64-apple-ios15.0"
        ;;

    ios-simulator-arm64)
        SDK="iphonesimulator"
        ARCH="arm64"
        TRIPLE="arm64-apple-ios15.0-simulator"
        ;;

    ios-simulator-x86_64)
        SDK="iphonesimulator"
        ARCH="x86_64"
        TRIPLE="x86_64-apple-ios15.0-simulator"
        ;;

    *)
        echo "Unknown target: ${TARGET}"
        exit 1
        ;;
esac

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

echo "Building ${TARGET}"
BUILD_DIR="${WORKSPACE_DIR}/build-${TARGET}-$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')"

cmake -S "${LLVM_SRC}/llvm" -B "${BUILD_DIR}" -G Ninja \
  -Wno-author \
  -Wno-deprecated \
  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
  -DCMAKE_SYSTEM_NAME=iOS \
  -DCMAKE_C_FLAGS="-w" \
  -DCMAKE_CXX_FLAGS="-w" \
  -DCMAKE_MACOSX_BUNDLE=OFF \
  -DCMAKE_OSX_SYSROOT="$(xcrun --sdk "${SDK}" --show-sdk-path)" \
  -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="15.0" \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="${TRIPLE}"

cmake --build "${BUILD_DIR}" --parallel "$(sysctl -n hw.ncpu)"
