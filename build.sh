#!/bin/bash
set -e

TARGET="${1:-}"
LLVM_TYPE="${2:-Native}"
BUILD_TYPE="${3:-Release}"

if [[ -z "${TARGET}" ]]; then
    echo "Usage: $0 <target> [llvm-type] [build-type]"
    echo
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

case "${LLVM_TYPE}" in
    Native|Cross-Host|Cross-CMake)
        ;;
    *)
        echo "Unknown LLVM type: ${LLVM_TYPE}"
        echo "LLVM types: Native, Cross-Host, Cross-CMake"
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
WORKSPACE_DIR="$(pwd)"
LLVM_ARCHIVE="llvm-project-${LLVM_VERSION}.src.tar.xz"
LLVM_SRC="${WORKSPACE_DIR}/llvm-src"

echo "Fetching and extracting LLVM ${LLVM_VERSION}"
curl -L "https://github.com/llvm/llvm-project/releases/download/llvmorg-${LLVM_VERSION}/${LLVM_ARCHIVE}" -o "${LLVM_ARCHIVE}"

tar -xf "${LLVM_ARCHIVE}"
mv "llvm-project-${LLVM_VERSION}.src" "${LLVM_SRC}"
rm "${LLVM_ARCHIVE}"

echo "Applying LLVM CMake patches for iOS"
perl -0pi -e 's/if\(NOT LLVM_NO_DEAD_STRIP\)\n\s+if\("\$\{CMAKE_SYSTEM_NAME\}" MATCHES "Darwin"\)/if(NOT LLVM_NO_DEAD_STRIP)\n      if("\${CMAKE_SYSTEM_NAME}" MATCHES "Darwin|iOS")/' "${LLVM_SRC}/llvm/cmake/modules/AddLLVM.cmake"
perl -0pi -e 's/CMAKE_SYSTEM_NAME MATCHES "Darwin\|FreeBSD/CMAKE_SYSTEM_NAME MATCHES "Darwin|iOS|FreeBSD/' "${LLVM_SRC}/llvm/cmake/modules/HandleLLVMOptions.cmake"

HOST_BUILD=""
if [[ "${LLVM_TYPE}" != "Native" ]]; then
    HOST_BUILD="${WORKSPACE_DIR}/build-host-$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')"
    
    echo "Building host TableGen utilities"
    cmake -S "${LLVM_SRC}/llvm" -B "${HOST_BUILD}" -G Ninja \
        -Wno-author \
        -Wno-deprecated \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DLLVM_ENABLE_PROJECTS=clang \
        -DLLVM_TARGETS_TO_BUILD="AArch64;X86"

    cmake --build "${HOST_BUILD}" --target llvm-tblgen clang-tblgen --parallel "$(sysctl -n hw.ncpu)"
fi

echo
echo "========================================"
echo "LLVM ${LLVM_VERSION}"
echo "Target:     ${TARGET}"
echo "Build type: ${BUILD_TYPE}"
echo "LLVM type:  ${LLVM_TYPE}"
echo "SDK:        ${SDK}"
echo "Arch:       ${ARCH}"
echo "Triple:     ${TRIPLE}"
echo "========================================"
echo

BUILD_DIR="${WORKSPACE_DIR}/build-${TARGET}-$(echo "${LLVM_TYPE}" | tr '[:upper:]' '[:lower:]')-$(echo "${BUILD_TYPE}" | tr '[:upper:]' '[:lower:]')"

echo "Building LLVM for ${TARGET} with CMake"
cmake -S "${LLVM_SRC}/llvm" -B "${BUILD_DIR}" -G Ninja \
  -Wno-author \
  -Wno-deprecated \
  -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
  $(if [[ "${LLVM_TYPE}" != "Cross-CMake" ]]; then echo "-DCMAKE_SYSTEM_NAME=iOS"; fi) \
  -DCMAKE_C_FLAGS="-w" \
  -DCMAKE_CXX_FLAGS="-w" \
  $(if [[ "${LLVM_TYPE}" == "Cross-CMake" ]]; then echo "-DCMAKE_TOOLCHAIN_FILE=${LLVM_SRC}/llvm/cmake/platforms/iOS.cmake"; fi) \
  -DCMAKE_MACOSX_BUNDLE=OFF \
  -DCMAKE_OSX_SYSROOT="$(xcrun --sdk "${SDK}" --show-sdk-path)" \
  -DCMAKE_OSX_ARCHITECTURES="${ARCH}" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="15.0" \
  -DLLVM_ENABLE_PROJECTS="clang" \
  -DLLVM_TARGETS_TO_BUILD="AArch64;X86" \
  -DLLVM_DEFAULT_TARGET_TRIPLE="${TRIPLE}" \
  $(if [[ "${LLVM_TYPE}" != "Native" ]]; then echo "-DLLVM_NATIVE_TOOL_DIR=${HOST_BUILD}/bin"; fi)

cmake --build "${BUILD_DIR}" --parallel "$(sysctl -n hw.ncpu)"
