#!/bin/bash -ex

VERS="master v4.17 v4.16 v4.13 v4.12 v4.11 v4.10"

nproc=$(/usr/bin/getconf _NPROCESSORS_ONLN)
basedir=$(pwd)

function cleanup()
{
	cd "$basedir"
	[ ! -d linux ] || rm -rf linux
	[ ! -d "linux-$KERNEL" ] || rm -rf "linux-$KERNEL"
	make distclean || :
}

function clone_kernel()
{
	git clone https://github.com/torvalds/linux
}

function download_kernel()
{
	VER="$1"
	URL="https://www.kernel.org/pub/linux/kernel/v4.x/linux-$VER.tar.xz"
	wget "$URL"
	tar xf "linux-$VER.tar.xz"
}

function __prep_kernel()
{
	make mrproper
	make allmodconfig
	sed -i 's/CONFIG_RETPOLINE=/# CONFIG_RETPOLINE is not set/' .config
	make oldconfig
	make -j $nproc modules_prepare
	make -j $nproc headers_install
	KERNEL_HEADERS=$(pwd)/usr/include
	popd
}

function git_prep_kernel()
{
	VER="$1"

	pushd "linux"
	git checkout "$VER"
	__prep_kernel
}

function download_prep_kernel()
{
	VER="$1"

	pushd "linux-$VER"
	__prep_kernel
}

function build_lksctp()
{
	local use_builddir="$1"

	make distclean || :
	./bootstrap

	#CFLAGS="-Werror"
	if [ -n "$KERNEL_HEADERS" ]; then
		CFLAGS="$CFLAGS -I$KERNEL_HEADERS"
	fi
	export CFLAGS

	if [ "$use_builddir" == 1 ]; then
		mkdir build
		pushd build
		../configure
	else
		./configure
	fi

	make -j $nproc

	#make -j $nproc distcheck

	if [ "$use_builddir" == 1 ]; then
		popd
		rm -rf build
	fi
}

trap cleanup EXIT
if [ -z "$KERNEL" ]; then
	clone_kernel

	for ver in $VERS; do
		git_prep_kernel "$ver"
		build_lksctp
		build_lksctp 1
	done
else
	download_kernel "$KERNEL"
	download_prep_kernel "$KERNEL"
	build_lksctp
	build_lksctp 1
fi
