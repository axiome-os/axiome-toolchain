#!/bin/bash
# mk-sdk.sh — refresh SDK from local axiomeOS checkout.
# For maintainers only; end users use the vendored SDK without needing an axiomeOS checkout.
set -e
ROOT=$(cd "$(dirname "$0")/.." && pwd)
SRC=${AXIOME_OS_SRC:?Set AXIOME_OS_SRC to path of axiomeOS checkout}
if [ ! -d "$SRC/kernel/userspace/libc" ]; then
  echo "axiomeOS not found at $SRC"
  echo "Set AXIOME_OS_SRC=/path/to/axiomeOS"
  exit 1
fi
SDK=$ROOT/sdk
echo "Refreshing SDK from $SRC -> $SDK"

mkdir -p $SDK/include $SDK/ldscripts $SDK/src
cp -v $SRC/kernel/userspace/libc/*.h $SDK/include/
cp -v $SRC/kernel/userspace/libc/*.c $SDK/src/
cp -v $SRC/kernel/userspace/libc.ld $SDK/ldscripts/
cp -v $SRC/kernel/userspace/link.ld $SDK/ldscripts/
echo "Docs + version stamp"
echo "SDK refreshed from $SRC on $(date -u)" > $SDK/VERSION
cat $SDK/VERSION
echo "Done. Now run: make libs"
