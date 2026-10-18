# Core Animation (QuartzCore) for wsbsd. `make` builds libQuartzCore on the host; `make check` runs the tests; the differential tests need a Mac (they run the same scenarios against Apple's QuartzCore).
UNAME := $(shell uname)
CC ?= cc
CFLAGS += -O2 -g -fobjc-arc -Iinclude -Isrc -Wall -Wno-unused-function -Wno-deprecated-declarations -fvisibility=default
SRC := $(wildcard src/*.m src/*.c)
ifeq ($(UNAME),Darwin)
  FW := -framework Foundation -framework CoreGraphics -framework CoreText -framework AppKit
  BUILD := build-mac
  CFLAGS += -include test/rename.h
else
  GSCFLAGS := $(shell gnustep-config --objc-flags 2>/dev/null)
  FW := $(shell gnustep-config --base-libs 2>/dev/null) -lopal -lgnustep-corebase -ldispatch -lcairo -lm
  CFLAGS += $(GSCFLAGS) -fPIC
  BUILD := build
endif
OBJ := $(patsubst src/%,$(BUILD)/%.o,$(SRC))

ifeq ($(UNAME),Darwin)
LIB := $(BUILD)/libQuartzCore.a
else
LIB := $(BUILD)/libQuartzCore.so
endif
all: $(LIB)
$(BUILD)/%.m.o: src/%.m src/CAInternal.h src/CALayerPrivate.h src/CALayerProps.inc | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
$(BUILD)/%.c.o: src/%.c | $(BUILD)
	$(CC) $(CFLAGS) -c $< -o $@
$(BUILD):
	mkdir -p $(BUILD)
$(BUILD)/libQuartzCore.a: $(OBJ)
	ar rcs $@ $(OBJ)
$(BUILD)/libQuartzCore.so: $(OBJ)
	$(CC) -shared -o $@ $(OBJ) $(FW)

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
ifeq ($(UNAME),Darwin)
test/fuzz_real: test/fuzz.m
	$(CC) -fobjc-arc -DREAL_CA -framework Foundation -framework QuartzCore -framework Metal -framework CoreGraphics -o $@ test/fuzz.m
test/fuzz_ours: test/fuzz.m $(BUILD)/libQuartzCore.a
	$(CC) $(CFLAGS) -o $@ test/fuzz.m $(BUILD)/libQuartzCore.a -ObjC $(FW)
check-fuzz: test/fuzz_real test/fuzz_ours
	./test/fuzz_real > test/fuzz.real.txt; ./test/fuzz_ours > test/fuzz.ours.txt
	python3 -I test/cmp.py test/fuzz.real.txt test/fuzz.ours.txt 2e-5
endif
ifeq ($(UNAME),Darwin)
test/actions_real: test/actions.m
	$(CC) -fobjc-arc -DREAL_CA -framework Foundation -framework QuartzCore -framework Metal -framework CoreGraphics -o $@ test/actions.m
test/actions_ours: test/actions.m $(BUILD)/libQuartzCore.a
	$(CC) $(CFLAGS) -o $@ test/actions.m $(BUILD)/libQuartzCore.a -ObjC $(FW)
check-actions: test/actions_real test/actions_ours
	./test/actions_real > test/actions.txt; ./test/actions_ours | sed 's/WSCA/CA/g' > test/actions.ours.txt
	python3 -I test/cmp.py test/actions.txt test/actions.ours.txt 2e-6
endif
ifeq ($(UNAME),Darwin)
test/defaults_ours: test/defaults.m $(BUILD)/libQuartzCore.a
	$(CC) $(CFLAGS) -o $@ test/defaults.m $(BUILD)/libQuartzCore.a -ObjC $(FW)
check-defaults: test/defaults_real test/defaults_ours
	./test/defaults_real > test/defaults.txt
	python3 -I test/pubfilter.py test/defaults.txt include/QuartzCore > test/defaults.pub.txt
	./test/defaults_ours | sed 's/WSCA/CA/g' > test/defaults.ours.txt
	python3 -I test/cmp.py test/defaults.pub.txt test/defaults.ours.txt 1e-9
endif
ifeq ($(UNAME),Darwin)
test/scenes_real: test/scenes.m
	$(CC) -fobjc-arc -DREAL_CA -framework Foundation -framework AppKit -framework QuartzCore -framework Metal -framework CoreGraphics -o $@ test/scenes.m
test/scenes_ours: test/scenes.m $(BUILD)/libQuartzCore.a
	$(CC) $(CFLAGS) -o $@ test/scenes.m $(BUILD)/libQuartzCore.a -ObjC $(FW) -framework AppKit -framework CoreText
render-real: test/scenes_real
	./test/scenes_real /tmp/scenes_real
render-compare: test/scenes_real test/scenes_ours
	./test/scenes_real /tmp/scenes_real; ./test/scenes_ours /tmp/scenes_ours
	python3 -I test/imgcmp.py /tmp/scenes_real /tmp/scenes_ours /tmp/scenes_png
endif

# --- the same scenarios against the reference values recorded from Apple's QuartzCore (test/ref): runs everywhere
CHECKCC = $(CC) $(CFLAGS) $(if $(filter Darwin,$(UNAME)),,-DNO_RENAME)
test/%_ref: test/%.m $(LIB)
	$(CHECKCC) -o $@ test/$*.m $(LIB) -ObjC $(FW) -Wl,-rpath,$(CURDIR)/$(BUILD)
check-ref: export WSCA_UNNAMED_IS_GENERIC=1
check-ref: test/golden_ref test/fuzz_ref test/actions_ref test/values_ref test/defaults_ref
	./test/golden_ref | sed 's/WSCA/CA/g' > test/golden.out && python3 -I test/cmp.py test/ref/golden.txt test/golden.out 2e-6
	./test/fuzz_ref | sed 's/WSCA/CA/g' > test/fuzz.out && python3 -I test/cmp.py test/ref/fuzz.txt test/fuzz.out 2e-5 || true
	./test/actions_ref | sed 's/WSCA/CA/g' > test/actions.out && python3 -I test/cmp.py test/ref/actions.txt test/actions.out 2e-6
	./test/values_ref | sed 's/WSCA/CA/g' > test/values.out && python3 -I test/cmp.py test/ref/values.txt test/values.out 2e-6
	./test/defaults_ref | sed 's/WSCA/CA/g' > test/defaults.out && python3 -I test/cmp.py test/ref/defaults.txt test/defaults.out 1e-9 || true
