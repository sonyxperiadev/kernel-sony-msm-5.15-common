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

for platform in $PLATFORMS; do \

    case $platform in
        nagara)
            DEVICE=$NAGARA
            COMPRESSED="false"
            APENDED_DTB="false"
            DTBO="true"
            SOCDTB="waipio-v2.dtb"
            ;;
    esac

    if [ $COMPRESSED = "true" ]; then
        comp=".gz"
    fi
    if [ $APENDED_DTB = "true" ]; then
        dtb="-dtb"
    fi
    for device in $DEVICE; do \
        (
            if [ ! $only_build_for ] || [ $device = $only_build_for ] ; then

                KERNEL_TMP=$KERNEL_TMP-${device}
                # Keep kernel tmp when building for a specific device or when using keep tmp
                [ ! "$keep_kernel_tmp" ] && [ ! "$only_build_for" ] && rm -rf "${KERNEL_TMP}"
                mkdir -p "${KERNEL_TMP}"

                # In case this is a dirty rebuild, delete all DTBs and DTBOs so that they
                # won't be erraneously copied from a build for a different device/platform
                find "$KERNEL_TMP/arch/arm64/boot/dts/{qcom,somc}/" \( -name *.dtb -o -name *.dtbo \) -delete 2>/dev/null || true

                echo "================================================="
                echo "Platform -> ${platform} :: Device -> $device"
                make O="$KERNEL_TMP" ARCH=arm64 \
                                          CROSS_COMPILE=aarch64-linux-android- \
                                          CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                                          -j$(nproc) ${BUILD_ARGS} ${CC:+CC="${CC}"} \
                                          aosp_${platform}_${device}_defconfig

                echo "The build may take up to 10 minutes. Please be patient ..."
                echo "Building new kernel image ..."
                echo "Logging to $KERNEL_TMP/build.log"
                make O="$KERNEL_TMP" ARCH=arm64 \
                     CROSS_COMPILE=aarch64-linux-android- \
                     CROSS_COMPILE_ARM32=arm-linux-androideabi- \
                     -j$(nproc) ${BUILD_ARGS} ${CC:+CC="${CC}"} \
                     >"$KERNEL_TMP"/build.log 2>&1;

                echo "Copying new kernel image ..."
                cp "$KERNEL_TMP/arch/arm64/boot/Image$comp$dtb" "$KERNEL_TOP/common-kernel/kernel$dtb-$device"
                if [ $APENDED_DTB = "false" ]; then
                    mkdir -p "$KERNEL_TOP/common-kernel/$device/"
                    # TODO: Be explicit about these names
                    cp "$KERNEL_TMP/arch/arm64/boot/dts/qcom/$SOCDTB" "$KERNEL_TOP/common-kernel/$device/"
                fi
                if [ $DTBO = "true" ]; then
                    # shellcheck disable=SC2046
                    # note: We want wordsplitting in this case.
                    $MKDTIMG create "$KERNEL_TOP"/common-kernel/dtbo-${device}.img $(find "$KERNEL_TMP"/arch/arm64/boot/dts/qcom/ -name "*.dtbo")
                fi

            fi
        )
    done
done


echo "================================================="
echo "Done!"
