#!/bin/bash

# Enable strict error handling:
#   -u: error on unset vars
#   -o pipefail: fail if any command in a pipeline fails
# Note: We do NOT use -e because the script handles errors manually.
set -uo pipefail

# Handle Ctrl+C (SIGINT): print message and exit
trap 'echo -e "\n${0##*/} execution was interrupted by Ctrl+C."; exit 1' SIGINT

. "${0%/*}/build_shared_vars.sh"

# -------------------------------------------------------------------------
# Associative Array: CLANG_VERSIONS
# -------------------------------------------------------------------------
# Description:
#   CLANG_VERSIONS is a Bash associative array that maps each supported
#   **Android version** to the Clang toolchain used to build that specific
#   release within the AOSP build environment.
#
#   Each key represents an Android OS version (e.g., "16", "15", "14"),
#   and the associated value provides the full path to the Clang
#   toolchain's bin/ directory that matches the compiler used for that
#   Android release.
#
# Ordering Requirement:
#   - The **most recent Android version MUST appear first**.
#   - Older Android versions must follow in strictly descending order.
#   - When adding support for a new Android release, insert its entry at
#     the beginning of the array to maintain correct ordering.
#
# Usage:
#   To retrieve the Clang toolchain path for a given Android version:
#
#       clang_path="${CLANG_VERSIONS[$android_version]}"
#
#   Example:
#       android_version="16"
#       clang_path="${CLANG_VERSIONS[$android_version]}"
#       echo "Using Clang for Android $android_version: $clang_path"
#
# Notes:
#   - Keys represent Android version numbers, *not* LLVM/Clang major versions.
#   - Ensure that ANDROID_ROOT is defined before referencing toolchain paths.
# -------------------------------------------------------------------------
declare -A CLANG_VERSIONS=(
    ['15']="$ANDROID_ROOT/prebuilts/clang/host/linux-x86/clang-r522817/bin/"
    ['14']="$ANDROID_ROOT/prebuilts/clang/host/linux-x86/clang-r487747c/bin/"
    ['13']="$ANDROID_ROOT/prebuilts/clang/host/linux-x86/clang-r450784d/bin/"
    ['12']="$ANDROID_ROOT/prebuilts/clang/host/linux-x86/clang-r416183b/bin/"
    ['11']="$ANDROID_ROOT/prebuilts/clang/host/linux-x86/clang-r353983c/bin/"
)

# Iterate through each version and return the first match
for version in "${!CLANG_VERSIONS[@]}"; do
    CLANG_PATH="${CLANG_VERSIONS[$version]}"
    if [ -d "$CLANG_PATH" ]; then
        BUILD_VERSION=$(basename "$(dirname "$CLANG_PATH")" | sed 's/clang-//')
        echo "Using Clang (build $BUILD_VERSION) from Android $version."
        CLANG="$CLANG_PATH"
        break
    fi
done

# Error check if no valid Clang path was found
# This should never happen
if [ -z "$CLANG" ]; then
    echo "Error: No valid Clang path found. Please check your Android root."
    exit 1
fi

# Build command
BUILD_ARGS="LLVM=1 LLVM_IAS=1 CC=clang \
${verbose_output:+KCFLAGS='-fcolor-diagnostics'}"

PATH=$CLANG:$PATH
# source shared parts
. "${0%/*}/build_shared.sh"
