cd "$KERNEL_TOP"/kernel

echo ""
echo "================================================="
echo "Your Environment:"
echo "ANDROID_ROOT: ${ANDROID_ROOT}"
echo "KERNEL_TOP  : ${KERNEL_TOP}"
echo "KERNEL_TMP  : ${KERNEL_TMP}"

BUILD_ARGS="${BUILD_ARGS} \
ARCH=arm64 \
CROSS_COMPILE=aarch64-linux-gnu- \
CROSS_COMPILE_ARM32=arm-linux-gnueabi- \
-j$(nproc) \
${UFDT_APPLY_OVERLAY:+DTC_OVERLAY_TEST_EXT=$UFDT_APPLY_OVERLAY}"

for platform in "${!PLATFORMS[@]}"; do
    if [ -z "${only_build_for:-}" ] || [ "$platform" = "${only_build_for:-}" ]; then
        # Retrieve the platform configuration.
        # TODO: Currently, there is no validation, and we rely on the assumption that
        # the associative array contains no errors. This approach is not safe and could
        # lead to issues if the array is malformed or contains unexpected data.
        # Validation should be added to ensure data integrity.
        eval ${PLATFORMS[$platform]}

        if [ "${COMPRESSED:-}" = "true" ]; then
            comp=".gz"
        fi
        if [ -z "${SOCDTB:-}" ]; then
            dtb="-dtb"
        fi

        # Set KERNEL_TMP_PLATFORM to either the value of build_directory (if set)
        # or default to $KERNEL_TMP/${platform} if build_directory is unset or empty.
        KERNEL_TMP_PLATFORM=${build_directory:-$KERNEL_TMP/${platform}}

        # Construct the 'make' command with build arguments and specify the output
        # directory for the kernel build. It is used for both loading the defconfig
        # and performing the build process.
        make_cmd="make $BUILD_ARGS O=$KERNEL_TMP_PLATFORM"

        # Keep kernel tmp when building for a specific platform or when using keep tmp
        [ "${keep_kernel_tmp:-}" != "true" ] && [ -z "${only_build_for:-}" ] && rm -rf "${KERNEL_TMP_PLATFORM}"
        mkdir -p "${KERNEL_TMP_PLATFORM}"

        PLATFORM_KERNEL_OUT=$KERNEL_TOP/common-kernel/$platform
        mkdir -p "$PLATFORM_KERNEL_OUT"

        # In case this is a dirty rebuild, delete all DTBs and DTBOs so that they
        # won't be erroneously copied from a build for a different platform
        find "$KERNEL_TMP_PLATFORM/arch/arm64/boot/dts/{qcom,somc}/" \( -name *.dtb -o -name *.dtbo \) -delete 2>/dev/null || true

        # Truncate the log at the start of the build for a specific platform.
        : > "$KERNEL_TMP_PLATFORM/build.log"

        echo ""
        echo "================================================="
        echo "Platform -> ${platform}"

        echo "The build may take up to 10 minutes. Please be patient ..."
        echo "Building new kernel image ..."
        echo "Logging to $KERNEL_TMP_PLATFORM/build.log"

        # Load the defconfig, log output, and check for errors.
        $make_cmd aosp_${platform}_defconfig 2>&1 | log_pipeline
        check_error "Can't find aosp_${platform}_defconfig."

        # Run the build, log output, and check for errors.
        $make_cmd 2>&1 | log_pipeline
        check_error "Build failed. See $KERNEL_TMP_PLATFORM/build.log for details."

        echo "Copying new kernel image ..."
        cp "$KERNEL_TMP_PLATFORM/arch/arm64/boot/Image${comp:-}${dtb:-}" "$PLATFORM_KERNEL_OUT/kernel${dtb:-}"
        check_error "Failed to copy kernel image to $PLATFORM_KERNEL_OUT/"

        # If SOCDTB is specified, copy DTB files to the output directory.
        if [ -n "${SOCDTB:-}" ]; then
            mkdir -p "$PLATFORM_KERNEL_OUT/dtb/"
            cp "$KERNEL_TMP_PLATFORM/arch/arm64/boot/dts/qcom/$SOCDTB" "$PLATFORM_KERNEL_OUT/dtb/"
            check_error "Failed to copy $SOCDTB to $PLATFORM_KERNEL_OUT/dtb/"
        fi

        # If DTBO creation is enabled, generate DTBO files for each device.
        if [ "${DTBO:-}" = "true" ]; then
            for device in $DEVICES; do
                dtbo="$KERNEL_TMP_PLATFORM/arch/arm64/boot/dts/qcom/${SOC}-${platform}-${device}_generic-overlay.dtbo"
                dtbo_out="$PLATFORM_KERNEL_OUT/dtbo-${device}.img"
                echo "Creating $dtbo_out ..."
                $MKDTIMG create "$dtbo_out" $dtbo
                check_error "Failed to create DTBO for device $device using $dtbo"
            done
        fi

        # Normalize permissions. Set all files under $PLATFORM_KERNEL_OUT to 644.
        # Some files, such as the kernel image, may be marked executable (755) by
        # the build system.
        find "$PLATFORM_KERNEL_OUT/" -type f | xargs chmod 644
    fi
done

echo ""
echo "================================================="
echo "Done!"
