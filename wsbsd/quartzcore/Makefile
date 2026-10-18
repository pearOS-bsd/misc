# Core Animation (QuartzCore) for wsbsd. `make` builds libQuartzCore on the host; `make check` runs the tests; the differential tests need a Mac (they run the same scenarios against Apple's QuartzCore).
UNAME := $(shell uname)
CC ?= cc
CFLAGS += -O2 -g -fobjc-arc -Iinclude -Isrc -Wall -Wno-unused-function -Wno-deprecated-declarations -fvisibility=default
SRC := $(wildcard src/*.m src/*.c)
ifeq ($(UNAME),Darwin)
  FW := -framework Foundation -framework CoreGraphics
  BUILD := build-mac
  CFLAGS += -include test/rename.h
else
  GSCFLAGS := $(shell gnustep-config --objc-flags 2>/dev/null)
  FW := $(shell gnustep-config --base-libs 2>/dev/null) -lopal -lcairo -lm
  CFLAGS += $(GSCFLAGS) -fPIC
  BUILD := build
endif
OBJ := $(patsubst src/%,$(BUILD)/%.o,$(SRC))

all: $(BUILD)/libQuartzCore.a
$(BUILD)/%.m.o: src/%.m src/CAInternal.h src/CALayerPrivate.h src/CALayerProps.inc | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
$(BUILD)/%.c.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
$(BUILD):
	mkdir -p $(BUILD)
$(BUILD)/libQuartzCore.a: $(OBJ)
	ar rcs $@ $(OBJ)

# --- differential tests against the real QuartzCore (macOS only)
ifeq ($(UNAME),Darwin)
test/values_real: test/values.m
	$(CC) -fobjc-arc -DREAL_CA -framework Foundation -framework QuartzCore -framework CoreGraphics -o $@ test/values.m
test/values_ours: test/values.m $(BUILD)/libQuartzCore.a
	$(CC) $(CFLAGS) -o $@ test/values.m $(BUILD)/libQuartzCore.a -ObjC $(FW)
check-values: test/values_real test/values_ours
	./test/values_real > test/values.real.txt; ./test/values_ours > test/values.ours.txt
	python3 -I test/cmp.py test/values.real.txt test/values.ours.txt 2e-6
endif
clean:
	rm -rf build build-mac test/values_real test/values_ours
.PHONY: all clean check-values
ifeq ($(UNAME),Darwin)
test/golden_real: test/golden.m
	$(CC) -fobjc-arc -DREAL_CA -framework Foundation -framework QuartzCore -framework Metal -framework CoreGraphics -o $@ test/golden.m
test/golden_ours: test/golden.m $(BUILD)/libQuartzCore.a
	$(CC) $(CFLAGS) -o $@ test/golden.m $(BUILD)/libQuartzCore.a -ObjC $(FW)
check-golden: test/golden_real test/golden_ours
	./test/golden_real > test/golden.txt; ./test/golden_ours > test/golden.ours.txt
	python3 -I test/cmp.py test/golden.txt test/golden.ours.txt 2e-6
endif
