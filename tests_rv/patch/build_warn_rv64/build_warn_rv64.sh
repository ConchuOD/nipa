#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#
# Copyright (C) 2019 Netronome Systems, Inc.

# Modified tests/patch/build_allmodconfig_warn.sh for RISC-V builds

tmpfile_o=$(mktemp)
tmpfile_n=$(mktemp)

tmpdir0=$(mktemp -d)
tmpdir1=$(mktemp -d)
tmpdir2=$(mktemp -d)
random_date="Tue Oct 18 02:52:44 PM IST 2022"

rc=0

echo "Redirect to $tmpfile_o and $tmpfile_n"

HEAD=$(git rev-parse HEAD)

echo "Tree base:"
git log -1 --pretty='%h ("%s")' HEAD~

echo "Baseline building the tree"

make ARCH=riscv O=$tmpdir0 \
	allmodconfig CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	KBUILD_BUILD_TIMESTAMP=$random_date \
	-j $(nproc)

make ARCH=riscv O=$tmpdir0 \
	CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	KBUILD_BUILD_TIMESTAMP=$random_date \
	-j $(nproc) -k

rm -r build
git checkout -q HEAD~

echo "Building the tree before the patch"

make ARCH=riscv O=$tmpdir1 \
	allmodconfig CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE=riscv64-unknown-linux-gnu- \
	KBUILD_BUILD_TIMESTAMP=$random_date \
	-j $(nproc)

make ARCH=riscv O=$tmpdir1 \
	CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu"- \
	KBUILD_BUILD_TIMESTAMP=$(random_date) \
	-j $(nproc) -k \
	2> >(tee $tmpfile_o >&2)
incumbent=$(grep -i -c "\(warn\|error\)" $tmpfile_o)
rm -r build
echo "Building the tree with the patch"

git checkout -q $HEAD

make ARCH=riscv O=$tmpdir2 \
	allmodconfig CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	KBUILD_BUILD_TIMESTAMP=$random_date \
	-j $(nproc)

make ARCH=riscv O=$tmpdir2 \
	CC="ccache riscv64-unknown-linux-gnu-gcc" \
	CROSS_COMPILE="riscv64-unknown-linux-gnu-" \
	KBUILD_BUILD_TIMESTAMP=$random_date \
	-j $(nproc) -k \
	2> >(tee $tmpfile_n >&2) || rc=1

current=$(grep -i -c "\(warn\|error\)" $tmpfile_n)

echo "Errors and warnings before: $incumbent this patch: $current" >&$DESC_FD

if [ $current -gt $incumbent ]; then
  echo "New errors added" 1>&2
  diff -U 0 $tmpfile_o $tmpfile_n 1>&2

  echo "Per-file breakdown" 1>&2
  tmpfile_fo=$(mktemp)
  tmpfile_fn=$(mktemp)

  grep -i "\(warn\|error\)" $tmpfile_o | sed -n 's@\(^\.\./[/a-zA-Z0-9_.-]*.[ch]\):.*@\1@p' | sort | uniq -c \
    > $tmpfile_fo
  grep -i "\(warn\|error\)" $tmpfile_n | sed -n 's@\(^\.\./[/a-zA-Z0-9_.-]*.[ch]\):.*@\1@p' | sort | uniq -c \
    > $tmpfile_fn

  diff -U 0 $tmpfile_fo $tmpfile_fn 1>&2
  rm $tmpfile_fo $tmpfile_fn

  rc=1
fi

rm -rf $tmpdir0 $tmpdir1 $tmpdir2 $tmpfile_o $tmpfile_n

exit $rc
