#!/usr/bin/env bash
#
# Copyright (C) 2023 Edwiin Kusuma Jaya (ryuzenn)
#
# Simple Local Kernel Build Script
#
# Configured for Redmi Note 8 / ginkgo custom kernel source
#
# Setup build env with akhilnarang/scripts repo
#
# Use this script on root of kernel directory

SECONDS=0 # builtin bash timer
ZIPNAME="MilfKernel-AOSP-Ginkgo-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
ZIPNAME_KSU="MilfKernel-AOSP-Ginkgo-KSU-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
ZIPNAME_NH="MilfKernel-AOSP-Ginkgo-NetHunter-$(TZ=Asia/Jakarta date +"%Y%m%d-%H%M").zip"
TC_DIR="/workspace/toolchain/linux-x86"
CLANG_DIR="/workspace/toolchain/linux-x86/clang-r498229b"
GCC_64_DIR="/workspace/toolchain/aarch64-linux-android-4.9"
GCC_32_DIR="/workspace/toolchain/arm-linux-androideabi-4.9"
AK3_DIR="/workspace/android/AnyKernel3"
DEFCONFIG="vendor/ginkgo-perf_defconfig"
source .env

export PATH="$CLANG_DIR/bin:$PATH"
export KBUILD_BUILD_USER="MikaPrjkt"
export KBUILD_BUILD_HOST="MikaCloud"
export KBUILD_BUILD_VERSION="1"
export LOCALVERSION

if ! [ -d "${CLANG_DIR}" ]; then
echo "Clang not found! Cloning to ${TC_DIR}..."
if ! git clone --depth=1 https://android.googlesource.com/platform/prebuilts/clang/host/linux-x86 ${TC_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "${GCC_64_DIR}" ]; then
echo "gcc not found! Cloning to ${GCC_64_DIR}..."
if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9.git ${GCC_64_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if ! [ -d "${GCC_32_DIR}" ]; then
echo "gcc_32 not found! Cloning to ${GCC_32_DIR}..."
if ! git clone --depth=1 -b lineage-19.1 https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_arm_arm-linux-androideabi-4.9.git ${GCC_32_DIR}; then
echo "Cloning failed! Aborting..."
exit 1
fi
fi

if [[ $1 = "-k" || $1 = "--ksu" ]]; then
	echo -e "\nCleanup KernelSU first on local build\n"
	rm -rf KernelSU drivers/kernelsu

elif [[ $1 = "-NH" || $1 = "--NetHunter" ]]; then
	echo -e "\nBuild with Nethunter Support\n"
else
	echo -e "\nSet No KernelSU Install, just skip\n"
fi

# Set function for override kernel name and variants
curl -kLSs "https://raw.githubusercontent.com/kutemeikito/KernelSU/main/kernel/setup.sh" | bash -s main
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
echo -e "\nKSU Support, let's Make it On\n"

elif [[ $1 = "-NH" || $1 = "--NetHunter" ]]; then
echo -e "\nNetHunter Support, let's Make It On\n"
sed -i '$a\source "nethunter/Kconfig"' arch/arm64/Kconfig
sed -i 's/CONFIG_KSU=y/CONFIG_KSU=n/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
sed -i 's/CONFIG_LOCALVERSION="-MilfKernel-KSU"/CONFIG_LOCALVERSION="-MilfKernel-NH"/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
else
echo -e "\nKSU or NetHunter Not Support, let's build normal version\n"
sed -i 's/CONFIG_KSU=y/CONFIG_KSU=n/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
sed -i 's/CONFIG_LOCALVERSION="-MilfKernel-KSU"/CONFIG_LOCALVERSION="-MilfKernel"/g' arch/arm64/configs/vendor/ginkgo-perf_defconfig
fi

mkdir -p out
make O=out ARCH=arm64 $DEFCONFIG

echo -e "\nStarting compilation...\n"
make -j$(nproc --all) O=out ARCH=arm64 CC=clang LD=ld.lld AR=llvm-ar AS=llvm-as NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip CROSS_COMPILE=$GCC_64_DIR/bin/aarch64-linux-android- CROSS_COMPILE_ARM32=$GCC_32_DIR/bin/arm-linux-androideabi- CLANG_TRIPLE=aarch64-linux-gnu- Image.gz-dtb dtbo.img

if [ -f "out/arch/arm64/boot/Image.gz-dtb" ] && [ -f "out/arch/arm64/boot/dtbo.img" ]; then
echo -e "\nKernel compiled succesfully! Zipping up...\n"
git restore arch/arm64/configs/vendor/ginkgo-perf_defconfig
git restore arch/arm64/Kconfig
if [ -d "$AK3_DIR" ]; then
cp -r $AK3_DIR AnyKernel3
elif ! git clone -q https://github.com/0xTaaa/AnyKernel3; then
echo -e "\nAnyKernel3 repo not found locally and cloning failed! Aborting..."
exit 1
fi
cp out/arch/arm64/boot/Image.gz-dtb AnyKernel3
cp out/arch/arm64/boot/dtbo.img AnyKernel3
rm -f *zip
cd AnyKernel3
git checkout master &> /dev/null
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
zip -r9 "../$ZIPNAME_KSU" * -x '*.git*' README.md *placeholder
elif [[ $1 = "-NH" || $1 = "--NetHunter" ]]; then
zip -r9 "../$ZIPNAME_NH" * -x '*.git*' README.md *placeholder
else
zip -r9 "../$ZIPNAME" * -x '*.git*' README.md *placeholder
fi
cd ..
rm -rf AnyKernel3
rm -rf out/arch/arm64/boot
echo -e "\nCompleted in $((SECONDS / 60)) minute(s) and $((SECONDS % 60)) second(s) !"
if [[ $1 = "-k" || $1 = "--ksu" ]]; then
echo "Zip: $ZIPNAME_KSU"
elif [[ $1 = "-NH" || $1 = "--NetHunter" ]]; then
echo -e "Zip: $ZIPNAME_NH"
else
echo "Zip: $ZIPNAME"
fi
else
echo -e "\nCompilation failed!"
exit 1
fi
echo "Move Zip into Home Directory"
mv *.zip /workspace

echo "sending file to telegram"

#send normal variant to telegram
push_document() {
    curl -s -X POST \
        https://api.telegram.org/bot"$token"/sendDocument \
        -F chat_id="$chat_id" \
	-F document=@"$1" \
        -F "parse_mode=html" \
        -F "disable_web_page_preview=true"
}

push_document "/workspace/$ZIPNAME"

#send kernelSU variant to telegram
kirim_document() {
    curl -s -X POST \
        https://api.telegram.org/bot"$token"/sendDocument \
        -F chat_id="$chat_id" \
        -F document=@"$1" \
        -F "parse_mode=html" \
        -F "disable_web_page_preview=true"
}

kirim_document "/workspace/$ZIPNAME_KSU"

#send NetHunter Variant to telegram
send() {
curl -s -X POST \
https://api.telegram.org/bot"$token"/sendDocument \
 -F chat_id="$chat_id" \
 -F document=@"$1" \
 -F "parse_mode=html" \
 -F "disable_web_page_preview=true"
}

send "/workspace/$ZIPNAME_NH"
