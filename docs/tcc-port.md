# AxiomeOS TCC Port

TinyCC 0.9.28 ported to AxiomeOS target.

## What is ported

- **Host TCC binary** vendored at `sdk/tcc-host/bin/tcc` (x86-64, built from https://repo.or.cz/tinycc.git).
- **Driver `bin/axtcc`** (`bin/tcc` symlink) presents TCC CLI but emits AxiomeOS ELFs.
- **Fallback** to `x86_64-elf-gcc` if TCC cannot handle a construct (rare; TCC lacks some GNU extensions).

## Why a wrapper, not a fork

TCC's internal linker can generate ELFs, but AxiomeOS has strict loader contracts:
- fixed bases (`link.ld:13` at `0x10000000000`, `libc.ld:12` at `0x18000000000`)
- `--hash-style=sysv` only (no `gnu.hash` — see `kernel/dynlink.c:191` which reads DT_HASH nchain)
- `R_X86_64_*` reloc set (`dynlink.c:67-72`)
- PIE `ET_DYN` with `_start` at exact virtual address (kernel maps at link-time VA, bias 0 per `dynlink.h:15`)

TCC's built-in linker does not support custom `PHDRS`/`SECTIONS` with fixed PHDRS at those high bases without heavy patching. Instead:

1. `axtcc` compiles `.c → .o` with TCC (fast, `-c`), then
2. delegates linking to `bin/axld` which wraps `x86_64-elf-ld` with Axiome ldscripts.

This keeps TCC upgrades trivial (`make tcc-build`) and guarantees bit-identical output to the official `kernel/Makefile:118`.

## Compile flow

```
hello.c  --(axtcc/tcc -c -I sdk/include)--> hello.o (ELF relocatable)
hello.o + sdk/lib/crt0.o + sdk/lib/libc.sl  --(axld -> ld -pie -T link.ld --hash-style=sysv -z max-page-size=0x1000 -e _start)--> hello.elf
```

Flags injected (`axcc`/`axtcc`):
```
-ffreestanding -nostdlib -nostartfiles -fno-builtin -fno-stack-protector
-fPIC/-fpie -mno-red-zone -mcmodel=small -O2 -g -pipe -Wall -I sdk/include
```

## Verification

```bash
bin/tcc -v
bin/tcc -c examples/hello.c -o hello.o
bin/tcc -o hello.elf examples/hello.c
readelf -l hello.elf            # LOAD at 0x10000000000, DYNAMIC with NEEDED libc.sl
readelf -d hello.elf | grep NEEDED
readelf -r hello.elf            # only R_X86_64_JUMP_SLOT / RELATIVE etc.
```

All relocs must be among `R_X86_64_RELATIVE (8)`, `R_X86_64_GLOB_DAT (6)`, `R_X86_64_JUMP_SLOT (7)`, `R_X86_64_64 (1)` — the set handled by `kernel/dynlink.c:288-319`.

## Rebuilding TCC

```bash
make tcc-build
# clones tinycc, ./configure --prefix=sdk/tcc-host && make && make install
```

No local axiomeOS sources needed; host GCC/ld sufficient.

## Differences from upstream TCC

- Default include paths: `sdk/include` first, then TCC bundled (`stdarg.h` etc.), then host `/usr/include` for `stdint.h`/`stddef.h`.
- C library is not host glibc but `sdk/lib/libc.sl` (Axiome syscalls).
- Output is always Axiome ELF, never host Linux ELF with `ld-linux-x86-64.so.2` interpreter.

