# Foundation 1:1 behavioral cores — per-class standalone tests.
# Host build links the real Foundation only so OUR classes are under test.
CC ?= clang
OBJCFLAGS ?= -fobjc-arc -Wall -Wno-objc-root-class -g -O0
FOUNDATION_LDFLAGS ?= -framework Foundation

.PHONY: test
test: build/test_nsnull build/test_nsindexpath
	./build/test_nsnull
	./build/test_nsindexpath

build/test_nsnull: src/NSNull.m src/NSNull.h test/test_nsnull.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSNull.m test/test_nsnull.m $(FOUNDATION_LDFLAGS)

build/test_nsindexpath: src/NSIndexPath.m src/NSIndexPath.h test/test_nsindexpath.m
	@mkdir -p build
	$(CC) $(OBJCFLAGS) -o $@ src/NSIndexPath.m test/test_nsindexpath.m $(FOUNDATION_LDFLAGS)
