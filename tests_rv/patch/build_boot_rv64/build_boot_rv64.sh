#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2022 by Rivos Inc.

tmpdir=$(mktemp -d)
rc=0

PATH=$PATH CCACHE_DIR=$CCACHE_DIR make ARCH=riscv O=$tmpdir \
	allmodconfig CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	-j $(nproc) || rc=1

PATH=$PATH CCACHE_DIR=$CCACHE_DIR make ARCH=riscv O=$tmpdir \
	CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	-j $(nproc) -k || rc=1

if [ $rc -ne 0 ]; then
  echo "Build failed" >&$DESC_FD
else
  tuxrun --device qemu-riscv64 --tuxmake $tmpdir || rc=1
  if [ $rc -ne 0 ]; then
    echo "Boot/poweroff failed" >&$DESC_FD
  fi
fi

rm -rf $tmpdir

exit $rc
