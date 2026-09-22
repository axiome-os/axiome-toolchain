#!/bin/bash
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
BIN=$ROOT/bin
BUILD=$ROOT/build
SDK=$ROOT/sdk
echo "== SDK files exist =="
test -f $SDK/include/syscall.h
test -f $SDK/include/syscall_numbers.h
test -f $SDK/lib/crt0.o
test -f $SDK/lib/libc.sl
test -f $SDK/ldscripts/link.ld
test -f $SDK/ldscripts/libc.ld
test -x $BIN/axtcc
test -x $BIN/axcc
test -x $BIN/axld
echo "PASS files"

echo "== build hello via axtcc =="
$BIN/axtcc -o $BUILD/hello_tcc.elf $ROOT/examples/hello.c
test -f $BUILD/hello_tcc.elf
readelf -d $BUILD/hello_tcc.elf | grep -q "libc.sl" || (echo "missing NEEDED"; exit 1)
echo "PASS axtcc"

echo "== build hello via axcc =="
$BIN/axcc -o $BUILD/hello_axcc.elf $ROOT/examples/hello.c
readelf -l $BUILD/hello_axcc.elf | grep -q "10000000000" || (echo "wrong base"; exit 1)
echo "PASS axcc"

echo "== build hello via axld directly =="
$BIN/axtcc -c $ROOT/examples/hello.c -o $BUILD/hello.o
$BIN/axld -o $BUILD/hello_axld.elf $BUILD/hello.o $SDK/lib/crt0.o $SDK/lib/libc.sl
readelf -l $BUILD/hello_axld.elf | grep -q "LOAD"
echo "PASS axld"

echo "== check hash-style sysv =="
readelf -S $BUILD/hello_tcc.elf | grep -q "\.hash" || (echo "no .hash"; exit 1)
echo "PASS hash"

echo "All tests passed"
