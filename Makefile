# Legna Compiler - Makefile
# Platform: macOS ARM64

SDK_PATH := $(shell xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")

.PHONY: all clean test

all: legnac

legnac: src/legnac_darwin_arm64.s
	as -o /tmp/legnac.o src/legnac_darwin_arm64.s
	ld -o legnac /tmp/legnac.o -lSystem -syslibroot $(SDK_PATH) -e _main -arch arm64
	rm -f /tmp/legnac.o

test: legnac
	./tests/run_tests.sh

clean:
	rm -f legnac helloworld /tmp/legna_*
