#!/usr/bin/env bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"
SWORD_SOURCE_DIR="${PROJECT_ROOT}/Vendor/libsword"
BUILD_ROOT="${PROJECT_ROOT}/.build/sword-apple"
BUILD_TYPE="${BUILD_TYPE:-Release}"

DESTINATIONS=(
    macos
    ios
    ios-simulator
    tvos
    tvos-simulator
    visionos
    visionos-simulator
    watchos
    watchos-simulator
)

usage() {
    echo "Usage: $0 <destination|all>"
    echo
    echo "Destinations:"
    printf '  %s\n' "${DESTINATIONS[@]}"
}

contains_destination() {
    local candidate="$1"
    local destination

    for destination in "${DESTINATIONS[@]}"; do
        if [[ "${candidate}" == "${destination}" ]]; then
            return 0
        fi
    done

    return 1
}

configure_destination() {
    local destination="$1"

    case "${destination}" in
        macos)
            SDK_NAME="macosx"
            SYSTEM_NAME="Darwin"
            DEFAULT_ARCHITECTURES="arm64;x86_64"
            DEFAULT_DEPLOYMENT_TARGET="14.0"
            ;;
        ios)
            SDK_NAME="iphoneos"
            SYSTEM_NAME="iOS"
            DEFAULT_ARCHITECTURES="arm64"
            DEFAULT_DEPLOYMENT_TARGET="17.0"
            ;;
        ios-simulator)
            SDK_NAME="iphonesimulator"
            SYSTEM_NAME="iOS"
            DEFAULT_ARCHITECTURES="arm64;x86_64"
            DEFAULT_DEPLOYMENT_TARGET="17.0"
            ;;
        tvos)
            SDK_NAME="appletvos"
            SYSTEM_NAME="tvOS"
            DEFAULT_ARCHITECTURES="arm64"
            DEFAULT_DEPLOYMENT_TARGET="17.0"
            ;;
        tvos-simulator)
            SDK_NAME="appletvsimulator"
            SYSTEM_NAME="tvOS"
            DEFAULT_ARCHITECTURES="arm64;x86_64"
            DEFAULT_DEPLOYMENT_TARGET="17.0"
            ;;
        visionos)
            SDK_NAME="xros"
            SYSTEM_NAME="visionOS"
            DEFAULT_ARCHITECTURES="arm64"
            DEFAULT_DEPLOYMENT_TARGET="1.0"
            ;;
        visionos-simulator)
            SDK_NAME="xrsimulator"
            SYSTEM_NAME="visionOS"
            DEFAULT_ARCHITECTURES="arm64;x86_64"
            DEFAULT_DEPLOYMENT_TARGET="1.0"
            ;;
        watchos)
            SDK_NAME="watchos"
            SYSTEM_NAME="watchOS"
            DEFAULT_ARCHITECTURES="arm64;arm64_32"
            DEFAULT_DEPLOYMENT_TARGET="10.0"
            ;;
        watchos-simulator)
            SDK_NAME="watchsimulator"
            SYSTEM_NAME="watchOS"
            DEFAULT_ARCHITECTURES="arm64;x86_64"
            DEFAULT_DEPLOYMENT_TARGET="10.0"
            ;;
        *)
            echo "Error: Unsupported destination '${destination}'."
            usage
            exit 1
            ;;
    esac
}

build_destination() {
    local destination="$1"
    configure_destination "${destination}"

    local sdk_path
    local build_directory
    local library
    local architectures
    local deployment_target

    sdk_path="$(xcrun --sdk "${SDK_NAME}" --show-sdk-path)"
    build_directory="${BUILD_ROOT}/${destination}"
    library="${build_directory}/libsword.a"
    architectures="${ARCHITECTURES:-${DEFAULT_ARCHITECTURES}}"
    deployment_target="${DEPLOYMENT_TARGET:-${DEFAULT_DEPLOYMENT_TARGET}}"

    echo "Building SWORD for ${destination}"
    echo "SDK:           ${SDK_NAME}"
    echo "Architectures: ${architectures}"
    echo "Deployment:    ${deployment_target}"
    echo "Output:        ${library}"
    echo

    rm -rf "${build_directory}"

    cmake \
        -S "${SWORD_SOURCE_DIR}" \
        -B "${build_directory}" \
        -DCMAKE_BUILD_TYPE="${BUILD_TYPE}" \
        -DCMAKE_SYSTEM_NAME="${SYSTEM_NAME}" \
        -DCMAKE_OSX_SYSROOT="${sdk_path}" \
        -DCMAKE_OSX_ARCHITECTURES="${architectures}" \
        -DCMAKE_OSX_DEPLOYMENT_TARGET="${deployment_target}" \
        -DCMAKE_TRY_COMPILE_TARGET_TYPE=STATIC_LIBRARY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PROGRAM=NEVER \
        -DCMAKE_FIND_ROOT_PATH_MODE_LIBRARY=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_INCLUDE=ONLY \
        -DCMAKE_FIND_ROOT_PATH_MODE_PACKAGE=ONLY \
        -DSWORD_BUILD_UTILS=No \
        -DSWORD_BUILD_EXAMPLES=No \
        -DSWORD_BUILD_TESTS=OFF \
        -DSWORD_PYTHON_2=OFF \
        -DSWORD_PYTHON_3=OFF \
        -DSWORD_PERL=OFF \
        -DCMAKE_POLICY_VERSION_MINIMUM=3.5

    cmake \
        --build "${build_directory}" \
        --target sword_static \
        --parallel

    if [[ ! -f "${library}" ]]; then
        echo "Error: Static SWORD library was not created at ${library}."
        exit 1
    fi

    echo
    echo "Created ${library}"
    lipo -info "${library}"
}

if [[ $# -ne 1 ]]; then
    usage
    exit 1
fi

requested_destination="$1"

if [[ "${requested_destination}" == "all" ]]; then
    for destination in "${DESTINATIONS[@]}"; do
        build_destination "${destination}"
    done
elif contains_destination "${requested_destination}"; then
    build_destination "${requested_destination}"
else
    echo "Error: Unsupported destination '${requested_destination}'."
    usage
    exit 1
fi
