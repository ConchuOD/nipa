#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (c) 2022 by Rivos Inc.

tmpdir=$(mktemp -d)
rc=0

tuxmake --wrapper ccache --target-arch riscv -directory . \
	-o $tmpdir --toolchain gcc-11 --kconfig allmodconfig || rc=1

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
