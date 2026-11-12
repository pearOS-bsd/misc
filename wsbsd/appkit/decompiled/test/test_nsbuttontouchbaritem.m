/* test_nsbuttontouchbaritem.m */
#import "../src/NSButtonTouchBarItem.h"
static int gFails=0;
#define CHECK(c,m) do{if(!(c)){fprintf(stderr,"FAIL: %s\n",m);gFails++;}}while(0)
int main(void){@autoreleasepool{
  id tgt=[NSObject new];
  NSButtonTouchBarItem *b=[NSButtonTouchBarItem buttonTouchBarItemWithIdentifier:@"id1" title:@"Go" target:tgt action:@selector(copy)];
  CHECK([b isKindOfClass:[NSTouchBarItem class]],"is NSTouchBarItem");
  CHECK([b.identifier isEqual:@"id1"],"identifier from base init");
  CHECK([b.title isEqual:@"Go"],"title set by factory");
  CHECK(b.target==tgt && b.action==@selector(copy),"target/action set");
  CHECK(b.isEnabled,"enabled default YES");
  CHECK(b.image==nil && b.bezelColor==nil,"image/bezel nil");
  NSButtonTouchBarItem *d=[[NSButtonTouchBarItem alloc] initWithIdentifier:@"id2"];
  CHECK([d.title isEqual:@""],"default title empty");
  NSString *nt=nil; d.title=nt; CHECK([d.title isEqual:@""],"nil title -> empty");
  d.enabled=NO; CHECK(!d.isEnabled,"enabled set");
  id img=[NSObject new]; d.image=(id)img; CHECK(d.image==img,"image set");
  d.customizationLabel=@"L"; CHECK([d.customizationLabel isEqual:@"L"],"customizationLabel set");
  NSButtonTouchBarItem *i=[NSButtonTouchBarItem buttonTouchBarItemWithIdentifier:@"id3" image:(id)img target:nil action:NULL];
  CHECK([i.title isEqual:@""] && i.image==img,"image factory: empty title + image");
}
fprintf(stderr,gFails?"%d FAILED\n":"all passed\n",gFails); return gFails?1:0;}
