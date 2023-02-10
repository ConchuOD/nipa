#!/bin/bash
# SPDX-License-Identifier: GPL-2.0
#

tmpfile_b=$(mktemp)
tmpfile_n=$(mktemp)

rc=250

HEAD=$(git rev-parse HEAD)

git checkout -q HEAD~

output_b=$(../../tests_rv/patch/alphanumeric_selects/alphanumeric_selects.pl arch/riscv/Kconfig)

diff -y <(echo "$output_b") arch/riscv/Kconfig > $tmpfile_b
before=$(wc -l < $tmpfile_b)

git checkout -q $HEAD

output_n=$(../../tests_rv/patch/alphanumeric_selects/alphanumeric_selects.pl arch/riscv/Kconfig)

diff -y <(echo "$output_n") arch/riscv/Kconfig > $tmpfile_n
now=$(wc -l < $tmpfile_n)

echo "Out of order selects before the patch: $before and now $now" >&$DESC_FD

if [ $now -gt $before ]; then
  echo "New out of order content added" 1>&2
  echo "Ideally, sort depends first, the default second, selects (in alphanumerical order) third." 1>&2
  echo "Suggested fixups:" 1>&2
  diff -U0 $tmpfile_b $tmpfile_n | tail -n +4 | cut -c 2- 1>&2
else
  rc=0
fi

rm -rf $tmpfile_b $tmpfile_n
exit $rc
