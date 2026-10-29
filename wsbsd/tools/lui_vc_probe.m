#import <Cocoa/Cocoa.h>
#import <dlfcn.h>
#import <objc/message.h>
static void dump(NSView*v,int d){
  NSMutableString*s=[NSMutableString string];for(int i=0;i<d;i++)[s appendString:@"  "];
  NSRect f=v.frame;
  printf("%s%s %.1f,%.1f %.1fx%.1f",[s UTF8String],object_getClassName(v),f.origin.x,f.origin.y,f.size.width,f.size.height);
  if([v isKindOfClass:[NSTextField class]]){NSTextField*t=(id)v;printf(" font=%s %.1f str='%s'",[[t.font fontName]UTF8String],t.font.pointSize,[t.stringValue UTF8String]);}
  printf("\n");
  for(NSView*c in v.subviews)dump(c,d+1);
}
int main(){@autoreleasepool{
  [NSApplication sharedApplication];
  dlopen("/System/Library/PrivateFrameworks/LoginUIKit.framework/LoginUIKit",RTLD_NOW);
  const char*names[]={"LUI2BigTimeViewController","LUI2DateViewController","LUI2SecureTextFieldViewController","LUI2BatteryViewController","LUI2PowerViewController","LUI2AuthHintViewController","LUI2UserViewController",0};
  for(int i=0;names[i];i++){
    Class c=NSClassFromString([NSString stringWithUTF8String:names[i]]);
    printf("== %s %p\n",names[i],c);
    @try{
      id vc=[[c alloc] init];
      if([vc respondsToSelector:@selector(_fontSize)])printf("fontSize %f\n",((double(*)(id,SEL))objc_msgSend)(vc,@selector(_fontSize)));
      NSView*v=[vc view];
      NSWindow*w=[[NSWindow alloc]initWithContentRect:NSMakeRect(0,0,800,600) styleMask:0 backing:2 defer:NO];
      [w.contentView addSubview:v];[v layoutSubtreeIfNeeded];
      dump(v,0);
    }@catch(id e){printf("exc %s\n",[[e description]UTF8String]);}
  }
}}
