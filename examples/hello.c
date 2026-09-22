#include "stdio.h"
#include "syscall.h"

int main(int argc, char **argv) {
    (void)argc; (void)argv;
    printf("Hello from AxiomeOS SDK! pid=%d\n", (int)sys_getpid());
    return 0;
}
