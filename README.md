# AxiomeOS Toolchain (axiome-toolchain)

Standalone SDK + TCC port + linker for **AxiomeOS** — no local `axiomeOS` sources required.

This repo vendors the SDK (headers, `crt0.o`, `libc.sl`, `ldscripts`) so apps can be built offline, on any host with a cross or native toolchain.

## Layout

```
sdk/
  include/      # libc headers (syscall.h, stdio.h, string.h, stdlib.h, errno.h, signal.h, time.h, util.h, syscall_numbers.h)
  lib/
    crt0.o      # PIE startup (_start)
    libc.sl     # shared libc (DT_NEEDED, base 0x18000000000)
  ldscripts/
    link.ld     # app PIE base 0x10000000000
    libc.ld     # libc base 0x18000000000
  tcc-host/     # vendored TinyCC 0.9.28 (host binary + libtcc1.a + includes)
  src/          # vendored libc sources (for offline rebuild)

bin/
  axtcc         # TCC port driver (tcc -> axiome ELF via axld)
  tcc -> axtcc  # drop-in tcc alias
  axcc          # GCC driver (x86_64-elf-gcc -> axiome ELF)
  axld          # linker wrapper (x86_64-elf-ld with axiome defaults)

tools/
  mk-sdk.sh     # refresh SDK from local axiomeOS checkout (maintainers only)

examples/
  hello.c

build/          # output (hello.elf etc.)
```

## ABI

- **Apps**: `ET_DYN` PIE, `base 0x10000000000`, via `sdk/ldscripts/link.ld`
- **Libc**: `ET_DYN` shared at `0x18000000000`, `--hash-style=sysv`, soname `libc.sl`
- **Relocs**: `R_X86_64_RELATIVE`, `R_X86_64_GLOB_DAT`, `R_X86_64_JUMP_SLOT`, `R_X86_64_64` (see `kernel/dynlink.c:268`)
- **Syscalls**: `syscall` insn, `rax=n`, `rdi,rsi,rdx,r10,r8,r9` (see `kernel/userspace/libc/syscall.c:5`)
- **Entry**: `_start` from `crt0.c:7` (reads argc/argv/envp from stack, calls `main`, exits via `SYS_EXIT`)
- **Loader**: `kernel/elf.c:81` maps `PT_LOAD` segments, `elf.c:248` loads `DT_NEEDED` from `/Libraries/`, `/Binaries/`, `/bin/`, then `dynlink.c:321` applies relocations.

## Quick start

```bash
# 1. (optional) build SDK libs offline — already vendored, but rebuild if needed
make libs

# 2. build example via TCC port
make examples
# or explicitly:
bin/axtcc -o build/hello.elf examples/hello.c
bin/axcc  -o build/hello.elf examples/hello.c
bin/axld  -o build/hello.elf build/hello.o sdk/lib/crt0.o sdk/lib/libc.sl

# 3. inspect
readelf -l build/hello.elf
readelf -d build/hello.elf | grep NEEDED   # should show libc.sl
file build/hello.elf

# 4. test (host-checks ELF before QEMU)
make check

# 5. deploy to AxiomeOS disk image (requires built OS checkout)
cp build/hello.elf $AXIOME_OS_SRC/kernel/userspace/hello.elf
# then in axiomeOS checkout:
#   make disk.img && make run
```

## TCC port

- Real TinyCC 0.9.28 binary in `sdk/tcc-host/bin/tcc` (built from https://repo.or.cz/tinycc.git).
- `bin/axtcc` wraps it: compiles with `-nostdinc -I sdk/include` and links via `bin/axld` so output respects AxiomeOS bases/hashes.
- If TCC compilation fails (e.g., unsupported construct), `axtcc` falls back to `x86_64-elf-gcc` automatically.
- Installed as `bin/tcc` symlink for drop-in `tcc -o prog prog.c`.

```bash
bin/tcc -v
bin/tcc -c hello.c -o hello.o
bin/tcc -o hello.elf hello.c
bin/tcc -run hello.c            # host run (dev), uses sdk includes
```

## Linker

`bin/axld` defaults:

```
- pie -T sdk/ldscripts/link.ld --hash-style=sysv -z max-page-size=0x1000 -e _start
```

If output name contains `libc`, it uses `libc.ld` and `-shared` automatically.

Uses `x86_64-elf-ld` from the cross toolchain if available (e.g. in `PATH` or `$HOME/opt/cross/bin`), else host `ld -m elf_x86_64`.

## Offline SDK

End users do **not** need an axiomeOS checkout:

- Headers are vendored in `sdk/include`
- Lib sources vendored in `sdk/src` allow `make libs` without upstream
- Prebuilt `sdk/lib/crt0.o` and `sdk/lib/libc.sl` ship ready to link

Maintainers refresh via:

```bash
AXIOME_OS_SRC=/path/to/axiomeOS tools/mk-sdk.sh   # copies from axiomeOS checkout
make libs
```

## Testing

```bash
make check
# Verifies ELF: PIE, entry within .text, NEEDED libc.sl, 4K maxpagesize
```

## License

Same as axiomeOS (see upstream `LICENSE.txt`).
