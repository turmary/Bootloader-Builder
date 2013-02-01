#!/bin/bash -e
#
# Copyright (c) 2010-2013 Robert Nelson <robertcnelson@gmail.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.

unset STABLE
unset TESTING

DIR=$PWD
TEMPDIR=$(mktemp -d)

CCACHE=ccache

ARCH=$(uname -m)
SYST=$(uname -n)

STABLE="v2013.01"
#TESTING="v2013.01-rc3"

#LATEST_GIT="88ba6d530d5f30cc2cc3c91bbe4d28e60e96aca5"
LATEST_GIT="6ad77d88e57f6ab815ec7e85c5ac329054318c73"

unset GIT_OPTS
unset GIT_NOEDIT
LC_ALL=C git help pull | grep -m 1 -e "--no-edit" &>/dev/null && GIT_NOEDIT=1

if [ "${GIT_NOEDIT}" ] ; then
	echo "Detected git 1.7.10 or later, this script will pull via [git pull --no-edit]"
	GIT_OPTS+="--no-edit"
fi

mkdir -p ${DIR}/git/
mkdir -p ${DIR}/dl/
mkdir -p ${DIR}/deploy/

rm -rf ${DIR}/deploy/latest-bootloader.log || true

#export MIRROR="http://example.com"
#./build.sh
if [ ! "${MIRROR}" ] ; then
	MIRROR="http:"
fi

WGET="wget -c --directory-prefix=${DIR}/dl/"

armv5_embedded_toolchain () {
	#https://launchpad.net/gcc-arm-embedded/4.6/4.6-2012-q4-update/+download/gcc-arm-none-eabi-4_6-2012q4-20121016.tar.bz2
	armv5_ver="gcc-arm-none-eabi-4_6-2012q4"
	armv5_date="20121016"
	ARMV5_GCC_EMBEDDED="${armv5_ver}-${armv5_date}.tar.bz2"
	if [ ! -f ${DIR}/dl/${armv5_date} ] ; then
		echo "Installing gcc-arm-embedded toolchain"
		echo "-----------------------------"
		${WGET} https://launchpad.net/gcc-arm-embedded/4.6/4.6-2012-q4-update/+download/${ARMV5_GCC_EMBEDDED}
		touch ${DIR}/dl/${armv5_date}
		if [ -d ${DIR}/dl/${armv5_ver} ] ; then
			rm -rf ${DIR}/dl/${armv5_ver} || true
		fi
		tar xjf ${DIR}/dl/${ARMV5_GCC_EMBEDDED} -C ${DIR}/dl/
	fi

	if [ "x${ARCH}" == "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${DIR}/dl/${armv5_ver}/bin/arm-none-eabi-"
	fi
}

armv7_toolchain () {
	#https://launchpad.net/linaro-toolchain-binaries/+download
	#https://launchpad.net/linaro-toolchain-binaries/trunk/2012.04/+download/gcc-linaro-arm-linux-gnueabi-2012.04-20120426_linux.tar.bz2

	armv7_ver="2012.04"
	armv7_date="20120426"
	ARMV7_GCC="gcc-linaro-arm-linux-gnueabi-${armv7_ver}-${armv7_date}_linux.tar.bz2"
	if [ ! -f ${DIR}/dl/${armv7_date} ] ; then
		echo "Installing gcc-arm toolchain"
		echo "-----------------------------"
		${WGET} https://launchpad.net/linaro-toolchain-binaries/trunk/${armv7_ver}/+download/${ARMV7_GCC}
		touch ${DIR}/dl/${armv7_date}
		if [ -d ${DIR}/dl/${armv7_ver} ] ; then
			rm -rf ${DIR}/dl/${armv7_ver} || true
		fi
		tar xjf ${DIR}/dl/${ARMV7_GCC} -C ${DIR}/dl/
	fi

	if [ "x${ARCH}" == "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${DIR}/dl/gcc-linaro-arm-linux-gnueabi-${armv7_ver}-${armv7_date}_linux/bin/arm-linux-gnueabi-"
	fi
}

armv7hf_toolchain () {
	#https://launchpad.net/linaro-toolchain-binaries/+download
	#https://launchpad.net/linaro-toolchain-binaries/trunk/2012.12/+download/gcc-linaro-arm-linux-gnueabihf-4.7-2012.12-20121214_linux.tar.bz2

	armv7hf_ver="2012.12"
	armv7hf_date="20121214"
	armv7hf_gcc="gcc-linaro-arm-linux-gnueabihf-4.7-${armv7hf_ver}-${armv7hf_date}_linux.tar.bz2"
	if [ ! -f ${DIR}/dl/${armv7hf_date} ] ; then
		echo "Installing gcc-arm toolchain"
		echo "-----------------------------"
		${WGET} https://launchpad.net/linaro-toolchain-binaries/trunk/${armv7hf_ver}/+download/${armv7hf_gcc}
		touch ${DIR}/dl/${armv7hf_date}
		if [ -d ${DIR}/dl/${armv7hf_ver} ] ; then
			rm -rf ${DIR}/dl/${armv7hf_ver} || true
		fi
		tar xjf ${DIR}/dl/${armv7hf_gcc} -C ${DIR}/dl/
	fi

	if [ "x${ARCH}" == "xarmv7l" ] ; then
		#using native gcc
		CC=
	else
		CC="${DIR}/dl/gcc-linaro-arm-linux-gnueabihf-4.7-${armv7hf_ver}-${armv7hf_date}_linux/bin/arm-linux-gnueabihf-"
	fi
}

git_generic () {
	echo "Starting ${project} build for: ${BOARD}"
	echo "-----------------------------"

	RELEASE_VER="-r0"

	if [ ! -f ${DIR}/git/${project}/.git/config ] ; then
		git clone git://github.com/RobertCNelson/${project}.git ${DIR}/git/${project}/
	fi

	cd ${DIR}/git/${project}/
	git pull ${GIT_OPTS} || true
	git fetch --tags || true
	cd -

	if [ -d ${DIR}/build/${project} ] ; then
		rm -rf ${DIR}/build/${project} || true
	fi

	mkdir -p ${DIR}/build/${project}
	git clone --shared ${DIR}/git/${project} ${DIR}/build/${project}

	cd ${DIR}/build/${project}

	if [ "${GIT_SHA}" ] ; then
		echo "Checking out: ${GIT_SHA}"
		git checkout ${GIT_SHA} -b ${project}-scratch
	fi
}

git_cleanup () {
	cd ${DIR}/

	rm -rf ${DIR}/build/${project} || true

	echo "${project} build completed for: ${BOARD}"
	echo "-----------------------------"
}

build_at91bootstrap () {
	project="at91bootstrap"
	git_generic

	make CROSS_COMPILE=${CC} clean &> /dev/null
	make CROSS_COMPILE=${CC} ${AT91BOOTSTRAP_CONFIG}_defconfig
	echo "Building ${project}: ${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin"
	make CROSS_COMPILE=${CC} > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}/
	cp -v binaries/*.bin ${DIR}/deploy/${BOARD}/${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin
	md5sum=$(md5sum ${DIR}/deploy/${BOARD}/${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin | awk '{print $1}')
	echo "${BOARD}_${MIRROR}/deploy/${BOARD}/${AT91BOOTSTRAP_CONFIG}${RELEASE_VER}.bin_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log

	git_cleanup
}

build_omap_xloader () {
	project="x-loader"
	git_generic

	make ARCH=arm distclean

	XGIT_VERSION=$(git rev-parse --short HEAD)
	XGIT_MON=$(git show HEAD | grep Date: | awk '{print $3}')
	XGIT_DAY=$(git show HEAD | grep Date: | awk '{print $4}')

	make ARCH=arm distclean &> /dev/null
	make ARCH=arm CROSS_COMPILE=${CC} ${XLOAD_CONFIG}
	echo "Building ${project}: ${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}"
	make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ift > /dev/null

	mkdir -p ${DIR}/deploy/${BOARD}
	cp -v MLO ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}
	md5sum=$(md5sum ${DIR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION} | awk '{print $1}')
	echo "${BOARD}_${MIRROR}/deploy/${BOARD}/MLO-${BOARD}-${XGIT_MON}-${XGIT_DAY}-${XGIT_VERSION}_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log

	git_cleanup
}

halt_patching_uboot () {
	pwd
	echo "-----------------------------"
	echo "make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}"
	echo "make ARCH=arm CROSS_COMPILE=${CC} ${BUILDTARGET}"
	echo "-----------------------------"
	exit
}

file_save () {
	cp -v ./${filename_search} ${DIR}/${filename_id}
	md5sum=$(md5sum ${DIR}/${filename_id} | awk '{print $1}')
	check=$(ls ${DIR}/${filename_id}_* | head -n 1)
	if [ "x${check}" != "x" ] ; then
		rm -rf ${DIR}/${filename_id}_* || true
	fi
	touch ${DIR}/${filename_id}_${md5sum}
	echo "${BOARD}_${MIRROR}/${filename_id}_${md5sum}" >> ${DIR}/deploy/latest-bootloader.log
}

build_u_boot () {
	project="u-boot"
	git_generic

	make ARCH=arm CROSS_COMPILE=${CC} distclean
	UGIT_VERSION=$(git describe)

	if [ "${v2013_04_rc1}" ] ; then
		#enable u-boot features...
		git am "${DIR}/patches/v2013.04-rc1/0001-enable-bootz-and-generic-load-features.patch"

		#TI:
		git am "${DIR}/patches/v2013.04-rc1/0002-ti-convert-to-uEnv.txt-n-fixes.patch"
		#Should not be needed with v3.8.x
		git am "${DIR}/patches/v2013.04-rc1/0003-panda-temp-enable-pads-and-clocks-for-kernel.patch"

		#Freescale:
		git am "${DIR}/patches/v2013.04-rc1/0002-imx-convert-to-uEnv.txt-n-fixes.patch"

		#Atmel:
		git am "${DIR}/patches/v2013.04-rc1/0002-at91-convert-to-uEnv.txt-n-fixes.patch"
	fi

	if [ "${v2013_01}" ] ; then
		#enable u-boot features...
		git am "${DIR}/patches/v2013.01/0001-enable-bootz-and-generic-load-features.patch"

		#TI:
		git am "${DIR}/patches/v2013.01/0002-ti-convert-to-uEnv.txt-n-fixes.patch"
		#Should not be needed with v3.8.x
		git am "${DIR}/patches/v2013.01/0003-panda-temp-enable-pads-and-clocks-for-kernel.patch"

		#Freescale:
		git am "${DIR}/patches/v2013.01/0002-imx-convert-to-uEnv.txt-n-fixes.patch"

		#Atmel:
		git am "${DIR}/patches/v2013.01/0002-at91-convert-to-uEnv.txt-n-fixes.patch"
	fi

	if [ "x${BOARD}" == "xarndale5250" ] ; then
		git am "${DIR}/patches/v2012.10/0001-MegaPatch-add-arndale5250-support-from-http-git.lina.patch"
	fi

	unset BUILDTARGET
	if [ "${mx6qsabrelite_patch}" ] ; then
		git pull ${GIT_OPTS} git://github.com/RobertCNelson/u-boot.git mx6qsabrelite_v2011.12_linaro_lt_imx6
		BUILDTARGET="u-boot.imx"
	fi

	if [ "x${BOARD}" == "xmx23olinuxino" ] ; then
		RELEASE_VER="-r3"
		git pull ${GIT_OPTS} git://github.com/RobertCNelson/u-boot-boards.git imx233-v2013.01-r2
		git am "${DIR}/patches/v2013.01/0001-mx23_olinuxino-load-uEnv.txt-from-boot-in-2nd-partit.patch"
		BUILDTARGET="u-boot.sb"
	fi

	if [ -f "${DIR}/stop.after.patch" ] ; then
		echo "-----------------------------"
		pwd
		echo "-----------------------------"
		echo "make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}"
		echo "make ARCH=arm CROSS_COMPILE=${CC} ${BUILDTARGET}"
		echo "-----------------------------"
		exit
	fi

	uboot_filename="${BOARD}-${UGIT_VERSION}${RELEASE_VER}"

	mkdir -p ${DIR}/deploy/${BOARD}

	unset pre_built
	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.imx ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.sb ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${BOARD}/MLO-${uboot_filename} ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/deploy/${BOARD}/u-boot-${uboot_filename}.bin ] ; then
		pre_built=1
	fi

	if [ -f ${DIR}/force_rebuild ] ; then
		unset pre_built
	fi

	if [ ! "${pre_built}" ] ; then
		make ARCH=arm CROSS_COMPILE=${CC} ${UBOOT_CONFIG}
		echo "Building ${project}: ${uboot_filename}"
		time make ARCH=arm CROSS_COMPILE="${CCACHE} ${CC}" ${BUILDTARGET} > /dev/null

		unset UBOOT_DONE
		#Freescale targets just need u-boot.imx from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.imx ] ; then
			filename_search="u-boot.imx"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.imx"
			file_save
			UBOOT_DONE=1
		fi

		#Freescale mx23 targets just need u-boot.sb from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.sb ] ; then
			filename_search="u-boot.sb"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.sb"
			file_save
			UBOOT_DONE=1
		fi

		#SPL based targets, need MLO and u-boot.img from u-boot
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/MLO ] && [ -f ${DIR}/build/${project}/u-boot.img ] ; then 
			filename_search="MLO"
			filename_id="deploy/${BOARD}/MLO-${uboot_filename}"
			file_save

			filename_search="u-boot.img"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.img"
			file_save
			UBOOT_DONE=1
		fi

		#Samsung SPL
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/spl/u-boot-spl.bin ] && [ -f ${DIR}/build/${project}/u-boot.bin ] ; then
			filename_search="spl/u-boot-spl.bin"
			filename_id="deploy/${BOARD}/u-boot-spl-${uboot_filename}.bin"
			file_save

			filename_search="u-boot.bin"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.bin"
			file_save
			UBOOT_DONE=1
		fi

		#Just u-boot.bin
		if [ ! "${UBOOT_DONE}" ] && [ -f ${DIR}/build/${project}/u-boot.bin ] ; then
			filename_search="u-boot.bin"
			filename_id="deploy/${BOARD}/u-boot-${uboot_filename}.bin"
			file_save
			UBOOT_DONE=1
		fi
	else
		echo "-----------------------------"
		echo "Skipping Binary Build: as [${uboot_filename}] was previously built."
		echo "Override skipping with [touch force_rebuild] to force rebuild"
		echo "-----------------------------"
	fi

	git_cleanup
}

cleanup () {
	unset GIT_SHA
}

build_uboot_stable () {
	v2013_01=1
	if [ "${STABLE}" ] ; then
		GIT_SHA=${STABLE}
		build_u_boot
	fi
	unset v2013_01
}

build_uboot_testing () {
#	v2013_04_rc1=1
#	v2013_04_rc2=1
#	v2013_04_rc3=1
	if [ "${TESTING}" ] ; then
		GIT_SHA=${TESTING}
		build_u_boot
	fi
#	unset v2013_04_rc1
#	unset v2013_04_rc2
#	unset v2013_04_rc3
}

build_uboot_latest () {
	v2013_04_rc1=1
#	v2013_04_rc2=1
#	v2013_04_rc3=1
	if [ "${LATEST_GIT}" ] ; then
		GIT_SHA=${LATEST_GIT}
		build_u_boot
	fi
	unset v2013_04_rc1
#	unset v2013_04_rc2
#	unset v2013_04_rc3
}

am3517crane () {
	cleanup
	armv7_toolchain

	BOARD="am3517crane"
	UBOOT_CONFIG="am3517_crane_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

arndale5250 () {
	cleanup
	armv7hf_toolchain

	BOARD="arndale5250"
	UBOOT_CONFIG="arndale5250_config"

	GIT_SHA="v2012.10"
	build_u_boot

#	build_uboot_stable
#	build_uboot_testing
#	build_uboot_latest
}

at91sam9x5ek () {
	cleanup
	armv5_embedded_toolchain

	BOARD="at91sam9x5ek"
	GIT_SHA="8e099c3a47f11c03b1ebe5cbc8d7406063b55262"
	AT91BOOTSTRAP_CONFIG="at91sam9x5sduboot"
	build_at91bootstrap

	UBOOT_CONFIG="at91sam9x5ek_nandflash_config"

	build_uboot_stable
	build_uboot_testing

	UBOOT_CONFIG="at91sam9x5ek_mmc_config"
	build_uboot_latest
}

beagleboard () {
	cleanup
	armv7_toolchain

	BOARD="beagleboard"
	UBOOT_CONFIG="omap3_beagle_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

beaglebone () {
	cleanup
	armv7_toolchain

	BOARD="beaglebone"
	UBOOT_CONFIG="am335x_evm_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

igep00x0 () {
	cleanup
	armv7_toolchain

	BOARD="igep00x0"

	XLOAD_CONFIG="igep00x0_config"
	build_omap_xloader

	UBOOT_CONFIG="igep0020_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx23olinuxino () {
	cleanup
	if [ $(which elftosb) ] ; then
		armv7_toolchain

		BOARD="mx23olinuxino"
		UBOOT_CONFIG="mx23_olinuxino_config"
		GIT_SHA="v2013.01"
		build_u_boot

#		build_uboot_stable
#		build_uboot_testing
#		build_uboot_latest
	else
		echo "-----------------------------"
		echo "Skipping Binary Build of [mx23_olinuxino]: as elftosb is not installed."
		echo "See: http://eewiki.net/display/linuxonarm/iMX233-OLinuXino#iMX233-OLinuXino-elftosb"
		echo "-----------------------------"
	fi
}

mx51evk () {
	cleanup
	armv7_toolchain

	BOARD="mx51evk"
	UBOOT_CONFIG="mx51evk_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx53loco () {
	cleanup
	armv7_toolchain

	BOARD="mx53loco"
	UBOOT_CONFIG="mx53loco_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx6qsabrelite () {
	cleanup
	armv7_toolchain

	BOARD="mx6qsabrelite"
	UBOOT_CONFIG="mx6qsabrelite_config"

	mx6qsabrelite_patch=1
	GIT_SHA="v2011.12"
	build_u_boot
	unset mx6qsabrelite_patch

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

mx6qsabresd () {
	cleanup
	armv7_toolchain

	BOARD="mx6qsabresd"
	UBOOT_CONFIG="mx6qsabresd_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

odroidx () {
	cleanup
	armv7_toolchain

	BOARD="odroidx"
	UBOOT_CONFIG="odroidx_config"

#	enable_zImage_support=1
#	enable_uenv_support=1
#	build_uboot_stable
#	unset enable_uenv_support
#	unset enable_zImage_support

	odroidx_patch=1
#	build_uboot_testing
#	build_uboot_latest
	unset odroidx_patch
}

pandaboard () {
	cleanup
	armv7_toolchain

	BOARD="pandaboard"
	UBOOT_CONFIG="omap4_panda_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

rpib () {
	cleanup
	armv7_toolchain

	BOARD="rpib"
	UBOOT_CONFIG="rpi_b_config"

	build_uboot_stable
	build_uboot_testing
	build_uboot_latest
}

am3517crane
arndale5250
at91sam9x5ek
beagleboard
beaglebone
igep00x0
mx23olinuxino
mx51evk
mx53loco
mx6qsabrelite
mx6qsabresd
odroidx
pandaboard
rpib

