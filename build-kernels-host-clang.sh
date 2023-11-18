#!/bin/sh

. "${0%/*}/build_shared_vars.sh"

echo "Using Host Clang (ver $(clang -v 2>&1 | head -n1 | awk '{print $3}'))"

CROSS_COMPILE="aarch64-linux-gnu-"
CROSS_COMPILE_ARM32="arm-none-eabi-"

# Build command
BUILD_ARGS="LLVM=1 LLVM_IAS=1 CC=clang"

# source shared parts
. "${0%/*}/build_shared.sh"
