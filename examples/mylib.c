#include <stdio.h>
#include <string.h>

int c_add(int a, int b) {
    return a + b;
}

int c_factorial(int n) {
    int r = 1;
    for (int i = 2; i <= n; i++) r *= i;
    return r;
}

int c_strlen(const char *s) {
    return (int)strlen(s);
}

void c_hello(void) {
    printf("[C] hello from C!\n");
}
