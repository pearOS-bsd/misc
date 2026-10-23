/* .DS_Store round trip: icon places, a property list and 400 records (more than one page of the B-tree) are written by TDSStore and read back; the file must carry the Bud1 header and keep every value. */
#import "TFinderViews.h"
int main(int argc, char **argv)
{
	@autoreleasepool {
		NSString *dir = @"/tmp/wsbsd-dsstore-test"; [[NSFileManager defaultManager] removeItemAtPath: dir error: NULL]; [[NSFileManager defaultManager] createDirectoryAtPath: dir withIntermediateDirectories: YES attributes: nil error: NULL];
		TDSStore *w = [TDSStore storeForFolder: dir]; for (int i = 0; i < 400; i++) [w setIconLocation: NSMakePoint(66 + (i % 9) * 112, 46 + (i / 9) * 112) ofName: [NSString stringWithFormat: @"File number %d with a longer name.txt", i]];
		[w setIconLocation: NSMakePoint(10, 20) ofName: @"Îngrijirea.pdf"]; [w setIconLocation: NSMakePoint(30, 40) ofName: @"abc"]; [w setPlist: @{ @"iconSize": @64, @"arrangeBy": @"none", @"showItemInfo": @NO } forName: @"." sid: @"icvp"]; [w setValue: @1 type: @"long" forName: @"." sid: @"vSrn"]; [w setValue: @"icnv" type: @"type" forName: @"." sid: @"vstl"];
		if (![w write]) { printf("write failed\n"); return 1; }
		NSData *d = [NSData dataWithContentsOfFile: [dir stringByAppendingPathComponent: @".DS_Store"]]; const unsigned char *b = (const unsigned char *)[d bytes]; if ([d length] < 40 || b[3] != 1 || memcmp(b + 4, "Bud1", 4)) { printf("bad header\n"); return 1; }
		TDSStore *r = [TDSStore storeForFolder: dir]; int bad = 0, x, y;
		for (int i = 0; i < 400; i++) { NSString *n = [NSString stringWithFormat: @"File number %d with a longer name.txt", i]; if (![r iconLocationOfName: n x: &x y: &y] || x != 66 + (i % 9) * 112 || y != 46 + (i / 9) * 112) bad++; }
		if (![r iconLocationOfName: @"Îngrijirea.pdf" x: &x y: &y] || x != 10 || y != 20) bad++; if (![r iconLocationOfName: @"abc" x: &x y: &y] || x != 30 || y != 40) bad++;
		NSDictionary *vp = [r plistForName: @"." sid: @"icvp"]; if ([vp[@"iconSize"] intValue] != 64 || ![vp[@"arrangeBy"] isEqual: @"none"]) bad++; if (![[r valueForName: @"." sid: @"vstl"] isEqual: @"icnv"] || [[r valueForName: @"." sid: @"vSrn"] intValue] != 1) bad++;
		printf("%s records %lu bad %d\n", bad ? "FAILED" : "ok", (unsigned long)[r->_records count], bad); return bad ? 1 : 0;
	}
}
