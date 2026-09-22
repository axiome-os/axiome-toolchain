# AxiomeOS Linker (axld)

`bin/axld` — AxiomeOS user-linker wrapper.

## Purpose

Produce PIE ELFs consumable by `kernel/elf.c:81` + `kernel/dynlink.c:79`.

- Maps at **link-time VA, bias 0** (`dynlink.h:15` comment: load bias always zero).
- Fixed bases (see `kernel/Makefile:51` comment):
  - `sdk/ldscripts/link.ld:13`  → `0x10000000000` (apps)
  - `sdk/ldscripts/libc.ld:12` → `0x18000000000` (libc.sl)
- No interpreter (`PT_INTERP` unused), no ASLR beyond fixed mapping.
- Kernel's `elf_map_image` (`elf.c:82`) allocates frames per `PT_LOAD` `p_vaddr` and `p_memsz`.
- `elf_apply_relocations` (`dynlink.c:321`) eagerly binds `DT_RELA` + `DT_JMPREL`.

## Defaults

If user does not specify, `axld` injects:

```
- pie
-T sdk/ldscripts/link.ld      # or libc.ld if output name contains "libc"
--hash-style=sysv
-z max-page-size=0x1000
-e _start
```

`--hash-style=sysv` is **required**: kernel only reads `DT_HASH` (`dynlink.c:191` `rd32(buf+hoff+4)` for nchain). GNU hash alone would yield 0 syms.

`max-page-size=0x1000` keeps `LOAD` alignment at 4K (matches `kernel/Makefile:82` `-z max-page-size=0x1000`).

`-pie` produces an `ET_DYN`-like ELF (actually `ET_EXEC` with `FLAGS_1 PIE` on this toolchain, see `readelf -h`); kernel accepts both because `elf_valid` (`elf.c:61`) does not check `e_type`.

## Underlying linker

Prefers `x86_64-elf-ld` from the cross toolchain (found via `PATH` or `$HOME/opt/cross/bin`), else host `ld -m elf_x86_64` with same script. Both understand `PHDRS` with `PT_LOAD` flags 5/6 and `PT_DYNAMIC`.

## Comparison to kernel/Makefile

Kernel builds libc as:
```
$(LD) -shared -T userspace/libc.ld --hash-style=sysv -soname libc.sl -z max-page-size=0x1000 -o $@ $(LIBC_OBJS)   # kernel/Makefile:113
```
and apps as:
```
$(LD) -pie -T userspace/link.ld --hash-style=sysv -z max-page-size=0x1000 -e _start -o $@ $^   # kernel/Makefile:120
```
`axld` replicates exactly; `axcc`/`axtcc` invoke it as:

```
axld -o hello.elf hello.o sdk/lib/crt0.o sdk/lib/libc.sl
```

`crt0.o` must be present (provides `_start` per `userspace/libc/crt0.c:7`); `libc.sl` provides `DT_NEEDED` (`dynlink.c:150` `DT_NEEDED` → `elf_lib_dirs` search in `elf.c:24`).

## Usage

```bash
bin/axld -o hello.elf hello.o sdk/lib/crt0.o sdk/lib/libc.sl
bin/axld -o libc.sl --shared -T sdk/ldscripts/libc.ld *.o   # libc build
readelf -l hello.elf
readelf -d hello.elf | grep NEEDED   # [libc.sl]
```

All flags are forwarded, so overrides work: `axld -T my.ld --hash-style=both ...`.

## Standalone

Vendored `sdk/ldscripts/*.ld` makes the linker SDK self-contained — no axiomeOS checkout needed at link time.

