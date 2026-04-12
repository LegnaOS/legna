# Legna Compiler - Makefile
# Platform: macOS ARM64
# Modular build: src/macos_arm64/*.s

SDK_PATH := $(shell xcrun --show-sdk-path 2>/dev/null || echo "/Library/Developer/CommandLineTools/SDKs/MacOSX.sdk")
SRC_DIR  := src/macos_arm64
BUILD    := build

SRCS := $(wildcard $(SRC_DIR)/*.s)
OBJS := $(patsubst $(SRC_DIR)/%.s,$(BUILD)/%.o,$(SRCS))

.PHONY: all clean test

all: legnac

$(BUILD):
	mkdir -p $(BUILD)

$(BUILD)/%.o: $(SRC_DIR)/%.s $(SRC_DIR)/defs.inc | $(BUILD)
	as -o $@ $<

legnac: $(OBJS)
	ld -o legnac $(OBJS) -lSystem -syslibroot $(SDK_PATH) -e _main -arch arm64 -dead_strip -x

test: legnac
	./tests/run_tests.sh

clean:
	rm -rf $(BUILD) legnac helloworld /tmp/legna_*
