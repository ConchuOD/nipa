#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2022 by Rivos Inc.

tmpdir=$(mktemp -d)
rc=0

tuxmake --wrapper ccache --target-arch riscv --directory . \
	-o $tmpdir --toolchain clang-nightly --kconfig allmodconfig LLVM=1 \
	-e PATH=$PATH

make ARCH=riscv LLVM=1 O=$tmpdir \
	allmodconfig CC="ccache clang" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	-j $(nproc) || rc=1

make ARCH=riscv LLVM=1 O=$tmpdir \
	CC="ccache clang" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	-j $(nproc) -k || rc=1

if [ $rc -ne 0 ]; then
  echo "Build failed" >&$DESC_FD
else
  tuxrun --device qemu-riscv64 --tuxmake $tmpdir -e PATH=$PATH || rc=1
  if [ $rc -ne 0 ]; then
    echo "Boot/poweroff failed" >&$DESC_FD
  fi
fi

rm -rf $tmpdir

exit $rc
