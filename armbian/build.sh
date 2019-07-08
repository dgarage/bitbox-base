#!/bin/bash

# BitBox Base: build Armbian base image
# 
# Script to automate the build process of the customized Armbian base image for the BitBox Base. 
# Additional information: https://digitalbitbox.github.io/bitbox-base
#
set -e

function usage() {
	echo "Build customized Armbian base image for BitBox Base"
	echo "Usage: ${0} [build|update]"
}

ACTION=${1:-"build"}

if ! [[ "${ACTION}" =~ ^(build|update)$ ]]; then
	usage
	exit 1
fi

case ${ACTION} in
	build|update)
		if ! which git >/dev/null 2>&1 || ! which docker >/dev/null 2>&1; then
			echo
			echo "Build environment not set up, please check documentation at"
			echo "https://digitalbitbox.github.io/bitbox-base"
			echo
			exit 1
		fi

		git log --pretty=format:'%h' -n 1 > ./base/config/latest_commit

		if [ ! -d "armbian-build" ]; then 
			git clone https://github.com/armbian/build armbian-build
		fi
		cd armbian-build
		pushd .
		mkdir -p output/
		mkdir -p userpatches/overlay
		cp -aR ../base/* userpatches/overlay/					# copy scripts and configuration items to overlay
		cp -aR ../../build/* userpatches/overlay/				# copy additional software binaries to overlay
		cp -a  ../base/build/customize-image.sh userpatches/	# copy customize script to standard Armbian build hook
		[ -f "../base/build/build.conf" ] && source ../base/build/build.conf
		[ -f "../base/build/build-local.conf" ] && source ../base/build/build-local.conf

		rm -rf "userpatches/overlay/btcpayserver-docker"
		cd "userpatches/overlay"
		git clone "$BTCPAY_REPOSITORY"
		cd btcpayserver-docker
		git checkout "$BTCPAY_BRANCH"
		. ./build.sh -i
		cd Generated
		./pull-images.sh
		./save-images.sh ../../docker-images.tar
		popd .

		BOARD=${BOARD:-rock64}
		BUILD_ARGS="docker BOARD=${BOARD} KERNEL_ONLY=no KERNEL_CONFIGURE=no RELEASE=stretch BRANCH=default BUILD_DESKTOP=no WIREGUARD=no LIB_TAG=sunxi-5.0"
		if ! [ "${ACTION}" == "build" ]; then
			BUILD_ARGS="${BUILD_ARGS} CLEAN_LEVEL=oldcache PROGRESS_LOG_TO_FILE=yes"
		fi
		time ./compile.sh ${BUILD_ARGS}

		;;
esac
