REPO_ROOT := $(abspath .)
SDK := $(REPO_ROOT)/sdk
BIN := $(REPO_ROOT)/bin
BUILD := $(REPO_ROOT)/build

# Cross tools (if present, else host)
CC ?= $(HOME)/opt/cross/bin/x86_64-elf-gcc
LD ?= $(HOME)/opt/cross/bin/x86_64-elf-ld
ifeq (,$(wildcard $(CC)))
  CC := gcc
  LD := ld
endif

SDK_INC := $(SDK)/include
SDK_LIB := $(SDK)/lib
SDK_LD  := $(SDK)/ldscripts
TCC_BIN := $(SDK)/tcc-host/bin/tcc

.PHONY: all sdk libs tcc examples clean test check dist

all: sdk libs

sdk:
	@echo "SDK status:"
	@ls -lh $(SDK_INC)/*.h
	@ls -lh $(SDK_LD)/*.ld
	@test -f $(SDK_LIB)/libc.sl && echo "libs: OK" || echo "libs: need build (make libs)"

libs: $(SDK_LIB)/crt0.o $(SDK_LIB)/libc.sl tcc

# Rebuild SDK libs from vendored src (no axiomeOS needed)
$(SDK_LIB)/crt0.o: $(SDK)/src/crt0.c
	@mkdir -p $(SDK_LIB)
	$(CC) -ffreestanding -nostdlib -nostartfiles -fno-builtin -fno-stack-protector -fpie -fPIC -mno-red-zone -mcmodel=small -O2 -g -pipe -Wall -Wextra -I$(SDK_INC) -c $< -o $@

LIBC_SRCS := $(wildcard $(SDK)/src/*.c)
# exclude crt0 already built? crt0 is separate
LIBC_OBJS := $(patsubst $(SDK)/src/%.c,$(BUILD)/libc_%.o,$(filter-out $(SDK)/src/crt0.c,$(LIBC_SRCS)))

$(BUILD)/libc_%.o: $(SDK)/src/%.c
	@mkdir -p $(BUILD)
	$(CC) -ffreestanding -nostdlib -nostartfiles -fno-builtin -fno-stack-protector -fPIC -mcmodel=small -O2 -g -pipe -Wall -Wextra -I$(SDK_INC) -c $< -o $@

$(SDK_LIB)/libc.sl: $(LIBC_OBJS) $(SDK_LD)/libc.ld
	@mkdir -p $(SDK_LIB)
	$(LD) -shared -T $(SDK_LD)/libc.ld --hash-style=sysv -soname libc.sl -z max-page-size=0x1000 -o $@ $(LIBC_OBJS)

tcc:
	@if [ -x "$(TCC_BIN)" ]; then echo "TCC: $(TCC_BIN) OK"; else echo "TCC: building..."; $(MAKE) tcc-build; fi

tcc-build:
	@if [ ! -d /tmp/tcc-src ]; then git clone --depth 1 https://repo.or.cz/tinycc.git /tmp/tcc-src; fi
	@mkdir -p /tmp/tcc-build
	cd /tmp/tcc-src && ./configure --prefix=$(SDK)/tcc-host && make -j4 && make install || true
	@cp -f /tmp/tcc-src/tcc $(SDK)/tcc-host/bin/tcc || true
	@mkdir -p $(SDK)/tcc-host/include
	@cp -f /tmp/tcc-src/include/*.h $(SDK)/tcc-host/include/ || true
	@cp -f /tmp/tcc-src/libtcc1.a $(SDK)/tcc-host/lib/tcc/ || true

examples: $(BUILD)/hello.elf

$(BUILD)/hello.elf: examples/hello.c $(SDK_LIB)/crt0.o $(SDK_LIB)/libc.sl
	@mkdir -p $(BUILD)
	$(BIN)/axtcc -o $@ $<

# Alt builds via axcc and raw axld
examples-axcc: examples/hello.c
	$(BIN)/axcc -o $(BUILD)/hello_axcc.elf $<

examples-tcc: examples/hello.c
	$(BIN)/axtcc -o $(BUILD)/hello_tcc.elf $<

check: $(BUILD)/hello.elf
	@echo "=== readelf -l $(BUILD)/hello.elf ==="
	readelf -l $(BUILD)/hello.elf
	@echo "=== readelf -d $(BUILD)/hello.elf | grep NEEDED ==="
	readelf -d $(BUILD)/hello.elf | grep NEEDED || true
	@echo "=== file ==="
	file $(BUILD)/hello.elf
	@echo "=== SDK self-containment check ==="
	@test -f $(SDK_INC)/syscall.h && echo "syscall.h OK"
	@test -f $(SDK_INC)/syscall_numbers.h && echo "syscall_numbers.h OK"
	@test -f $(SDK_LIB)/libc.sl && echo "libc.sl OK"
	@test -f $(SDK_LIB)/crt0.o && echo "crt0.o OK"
	@test -f $(SDK_LD)/link.ld && echo "link.ld OK"
	@test -x $(BIN)/axtcc && echo "axtcc OK"
	@test -x $(BIN)/axld && echo "axld OK"

test: check
	@bash tests/test_sdk.sh

dist: all check
	@echo "Creating SDK tarball..."
	tar czf axiome-toolchain-$$(cat sdk/VERSION | head -1 | tr ' ' '_').tar.gz --exclude=build sdk bin tools examples docs Makefile README.md

clean:
	rm -rf $(BUILD)

distclean: clean
	rm -f $(SDK_LIB)/crt0.o $(SDK_LIB)/libc.sl

# Refresh SDK from local axiomeOS checkout (for SDK maintainers only)
refresh-sdk:
	@echo "Refreshing SDK from \$$AXIOME_OS_SRC ..."
	@bash tools/mk-sdk.sh

install: all
	@echo "Toolchain ready. Add $(BIN) to PATH:"
	@echo "  export PATH=$(BIN):$$PATH"
	@echo "  axtcc -o hello.elf hello.c   # TCC port"
	@echo "  axcc  -o hello.elf hello.c   # GCC port"
	@echo "  axld  -o hello.elf hello.o   # linker"

