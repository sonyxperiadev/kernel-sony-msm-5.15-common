set -e
# Check if mkdtimg tool exist
[ ! -f "$MKDTIMG" ] && MKDTIMG="$ANDROID_ROOT/prebuilts/misc/linux-x86/libufdt/mkdtimg"
[ ! -f "$MKDTIMG" ] && MKDTIMG="$ANDROID_ROOT/system/libufdt/utils/src/mkdtboimg.py"
[ ! -f "$MKDTIMG" ] && (echo "No mkdtbo script/executable found"; exit 1)


cd "$KERNEL_TOP"/kernel

echo "================================================="
echo "Your Environment:"
echo "ANDROID_ROOT: ${ANDROID_ROOT}"
echo "KERNEL_TOP  : ${KERNEL_TOP}"
echo "KERNEL_TMP  : ${KERNEL_TMP}"

BUILD_ARGS="${BUILD_ARGS} \
ARCH=arm64 \
CROSS_COMPILE=aarch64-linux-android- \
CROSS_COMPILE_ARM32=arm-linux-androideabi- \
-j$(nproc)"

for platform in $PLATFORMS; do \

    if [ ! $only_build_for ] || [ $platform = $only_build_for ] ; then

        case $platform in
            nagara)
                COMPRESSED="false"
                DTBO="true"
                SOCDTB="waipio-v2.dtb"
                ;;
        esac

        if [ "$COMPRESSED" = "true" ]; then
            comp=".gz"
        fi
        if [ ! "$SOCDTB" ]; then
            dtb="-dtb"
        fi

        KERNEL_TMP_PLATFORM=$KERNEL_TMP/${platform}
        BUILD_ARGS_PLATFORM="$BUILD_ARGS O=$KERNEL_TMP_PLATFORM"

        # Keep kernel tmp when building for a specific platform or when using keep tmp
        [ ! "$keep_kernel_tmp" ] && [ ! "$only_build_for" ] && rm -rf "${KERNEL_TMP_PLATFORM}"
        mkdir -p "${KERNEL_TMP_PLATFORM}"

        PLATFORM_KERNEL_OUT=$KERNEL_TOP/common-kernel/$platform
        mkdir -p "$PLATFORM_KERNEL_OUT"

        # In case this is a dirty rebuild, delete all DTBs and DTBOs so that they
        # won't be erroneously copied from a build for a different platform
        find "$KERNEL_TMP_PLATFORM/arch/arm64/boot/dts/{qcom,somc}/" \( -name *.dtb -o -name *.dtbo \) -delete 2>/dev/null || true

        echo "================================================="
        echo "Platform -> ${platform}"
        make $BUILD_ARGS_PLATFORM aosp_${platform}_defconfig

        echo "The build may take up to 10 minutes. Please be patient ..."
        echo "Building new kernel image ..."
        echo "Logging to $KERNEL_TMP_PLATFORM/build.log"
        make $BUILD_ARGS_PLATFORM >"$KERNEL_TMP_PLATFORM/build.log" 2>&1;

        echo "Copying new kernel image ..."
        cp "$KERNEL_TMP_PLATFORM/arch/arm64/boot/Image$comp$dtb" "$PLATFORM_KERNEL_OUT/kernel$dtb"
        if [ "$SOCDTB" ]; then
            mkdir -p "$PLATFORM_KERNEL_OUT/dtb/"
            cp "$KERNEL_TMP_PLATFORM/arch/arm64/boot/dts/qcom/$SOCDTB" "$PLATFORM_KERNEL_OUT/dtb/"
        fi
        if [ "$DTBO" = "true" ]; then
            DTBO_OUT="$PLATFORM_KERNEL_OUT/dtbo.img"
            echo "Creating $DTBO_OUT ..."
            # shellcheck disable=SC2046
            # note: We want wordsplitting in this case.
            $MKDTIMG create $DTBO_OUT $(find "$KERNEL_TMP_PLATFORM/arch/arm64/boot/dts/qcom/" -name "*.dtbo")
        fi

    fi
done


echo "================================================="
echo "Done!"
