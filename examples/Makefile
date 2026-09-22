SDK ?= ../sdk
BIN ?= ../bin

all: hello.elf

hello.elf: hello.c
	$(BIN)/axtcc -o $@ $<

hello-gcc.elf: hello.c
	$(BIN)/axcc -o $@ $<

clean:
	rm -f *.elf *.o

check:
	readelf -l hello.elf
	readelf -d hello.elf | grep -q "libc.sl" && echo "NEEDED libc.sl OK"
