/* dsstore_roundtrip IN OUT: reads a .DS_Store with TDSStore and writes it again; compare with tools/dsprobe/dsstore_check.py (the records must be identical). */
#import "TFinderViews.h"
int main(int argc, char **argv) { @autoreleasepool { TDSStore *s = [[TDSStore alloc] initWithPath: @(argv[1])]; printf("records %lu\n", (unsigned long)[s->_records count]); s->_path = @(argv[2]); return [s write] ? 0 : 1; } }
