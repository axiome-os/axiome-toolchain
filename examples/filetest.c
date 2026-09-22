#include "stdio.h"
#include "string.h"
#include "stdlib.h"
#include "syscall.h"

int main(int argc, char **argv){
    (void)argc;(void)argv;
    const char *msg = "Axiome SDK filetest\n";
    write(1, msg, strlen(msg));
    char *p = malloc(32);
    if(p){
        strcpy(p, "malloc works\n");
        write(1, p, strlen(p));
        free(p);
    }
    printf("printf works: %d\n", 42);
    return 0;
}
