# AxiomeOS SDK — offline, no local sources needed

## Contents

Vendored from the axiomeOS repository at SDK release time (see `sdk/VERSION`).

- `sdk/include/*.h` — libc UAPI headers
- `sdk/lib/crt0.o` — PIE startup (naked `_start`, calls `main`, `SYS_EXIT`)
- `sdk/lib/libc.sl` — shared libc (`ET_DYN`, DT_SONAME `libc.sl`)
- `sdk/ldscripts/*.ld` — fixed-base link scripts
- `sdk/src/*.c` — libc sources for offline rebuild (`make libs`)
- `sdk/tcc-host/*` — TinyCC host binary + `libtcc1.a`

## Headers

Copied from `kernel/userspace/libc/*.h`:

- `syscall.h` / `syscall_numbers.h` — single source of truth for numbers 0..72 (`kernel/syscall.h:7`)
- `errno.h`, `string.h`, `stdlib.h`, `stdio.h`, `signal.h`, `time.h`, `util.h`

Include as `#include "syscall.h"` (or `<syscall.h>`) with `-I sdk/include`.

`stdint.h`/`stddef.h`/`stdarg.h` come from host GCC or `sdk/tcc-host/include` (bundled).

## Rebuild from src (offline)

```bash
make libs
# rebuilds sdk/lib/crt0.o and sdk/lib/libc.sl from sdk/src/*.c + sdk/ldscripts/libc.ld
# no axiomeOS checkout needed
```

Flags mirror `kernel/Makefile:53-56`:
```
-ffreestanding -nostdlib -nostartfiles -fno-builtin -fno-stack-protector
-fPIC (libc) / -fpie (apps) -mno-red-zone -mcmodel=small -O2 -g -pipe -Wall -I sdk/include
```

## Fresh SDK from upstream

Maintainers only:

```bash
AXIOME_OS_SRC=/path/to/axiomeOS tools/mk-sdk.sh
make libs
```

End users never run this — the SDK ships prebuilt.

## App example

```c
// hello.c
#include "stdio.h"
#include "syscall.h"
int main(){ printf("hi %d\n", (int)sys_getpid()); return 0; }
```

```bash
bin/axtcc -o hello.elf hello.c   # or bin/axcc
readelf -l hello.elf             # check LOAD at 0x10000000000
```

Deploy to OS image (requires axiomeOS checkout with built disk):

```bash
cp hello.elf $AXIOME_OS_SRC/kernel/userspace/hello.elf
(cd $AXIOME_OS_SRC && make disk.img && make run)
```

