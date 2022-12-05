#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#

tmpfile_b=$(mktemp)
tmpfile_n=$(mktemp)

rc=1

HEAD=$(git rev-parse HEAD)

git checkout -q HEAD~

../../tests_rv/patch/alphanumeric_selects/alphanumeric_selects.pl arch/riscv/Kconfig > $tmpfile_b

before=$(diff -y  --suppress-common-lines $tmpfile_b arch/riscv/Kconfig | wc -l)

git checkout -q $HEAD

../../tests_rv/patch/alphanumeric_selects/alphanumeric_selects.pl arch/riscv/Kconfig > $tmpfile_n

now=$(diff -y  --suppress-common-lines $tmpfile_n arch/riscv/Kconfig | wc -l)

echo "Out of order selects before the patch: $before and now $now" >&$DESC_FD

if [ $now -gt $before ]; then
  echo "New out of order selects added" 1>&2
else
  rc=0
fi

rm -rf $tmpfile_b $tmpfile_n
exit $rc
