# Copyright 2015 The Android Open Source Project
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#      http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

BUILD_KERNEL := false

ifeq ($(BUILD_KERNEL),false)

PLATFORM_KERNEL_OUT := $(KERNEL_PATH)/common-kernel/$(PRODUCT_PLATFORM)

ifeq ($(BOARD_INCLUDE_DTB_IN_BOOTIMG), true)
    # AOSP will concatenate all these into a single dtb.img
    BOARD_PREBUILT_DTBIMAGE_DIR := $(PLATFORM_KERNEL_OUT)/dtb/
else
    dtb := "-dtb"
endif

ifeq ($(TARGET_NEEDS_DTBOIMAGE),true)
    BOARD_PREBUILT_DTBOIMAGE := $(PLATFORM_KERNEL_OUT)/dtbo-$(TARGET_DEVICE).img
endif

LOCAL_KERNEL := $(PLATFORM_KERNEL_OUT)/kernel$(dtb)

PRODUCT_COPY_FILES += \
    $(LOCAL_KERNEL):kernel

endif
