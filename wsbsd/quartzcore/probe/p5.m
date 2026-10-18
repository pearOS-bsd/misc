#import <Foundation/Foundation.h>
#import <QuartzCore/QuartzCore.h>
#import <Metal/Metal.h>
#import <objc/runtime.h>
static CARenderer *R; static CALayer *L; static CAShapeLayer *S; static CATextLayer *T; static CAGradientLayer *G; static CAReplicatorLayer *RP;
static void ctx(CALayer *l){
  id<MTLDevice> dev=MTLCreateSystemDefaultDevice();
  MTLTextureDescriptor *td=[MTLTextureDescriptor texture2DDescriptorWithPixelFormat:MTLPixelFormatBGRA8Unorm width:100 height:100 mipmapped:NO]; td.usage=MTLTextureUsageRenderTarget|MTLTextureUsageShaderRead;
  static NSMutableArray *keep; if(!keep) keep=[NSMutableArray new];
  CARenderer *r=[CARenderer rendererWithMTLTexture:[dev newTextureWithDescriptor:td] options:nil]; [keep addObject:r];
  r.layer=l; r.bounds=CGRectMake(0,0,400,300); [CATransaction flush];
}
static void rep(const char *what, CALayer *l){
  NSArray *keys=[l animationKeys]; printf("%-28s ->",what);
  if(!keys.count) printf(" none");
  for(NSString *k in keys){ CAAnimation *a=[l animationForKey:k]; printf(" [%s %s",[k UTF8String],class_getName([a class]));
    if([a isKindOfClass:[CATransition class]]){CATransition*t=(CATransition*)a; printf(" type=%s sub=%s sp=%g ep=%g filter=%s",[t.type UTF8String],[t.subtype UTF8String]?:"nil",t.startProgress,t.endProgress,[[t.filter description] UTF8String]);}
    printf("]"); }
  printf("\n"); [l removeAllAnimations];
}
int main(void){ @autoreleasepool {
  L=[CALayer layer]; L.frame=CGRectMake(10,20,100,50); L.backgroundColor=CGColorCreateGenericRGB(1,1,1,1); L.borderColor=CGColorCreateGenericRGB(1,1,1,1); L.shadowColor=CGColorCreateGenericRGB(0,0,0,1); ctx(L); [L removeAllAnimations];
  { L.bounds=CGRectMake(0,0,5,5); rep("bounds",L); }; { L.position=CGPointMake(1,1); rep("position",L); }; { L.zPosition=3; rep("zPosition",L); }; { L.anchorPoint=CGPointMake(.2,.2); rep("anchorPoint",L); };
  { L.anchorPointZ=2; rep("anchorPointZ",L); }; { L.transform=CATransform3DMakeScale(2,2,1); rep("transform",L); }; { L.frame=CGRectMake(5,5,50,50); rep("frame",L); };
  { L.hidden=YES; rep("hidden",L); }; { L.hidden=NO; rep("unhidden",L); }; { L.doubleSided=NO; rep("doubleSided",L); }; { L.geometryFlipped=YES; rep("geometryFlipped",L); };
  { L.sublayerTransform=CATransform3DMakeScale(2,2,1); rep("sublayerTransform",L); }; { L.masksToBounds=YES; rep("masksToBounds",L); }; { L.mask=[CALayer layer]; rep("mask",L); };
  { L.contents=(__bridge id)CGColorCreateGenericRGB(1,0,0,1); rep("contents",L); }; { L.contentsRect=CGRectMake(0,0,.5,.5); rep("contentsRect",L); }; { L.contentsGravity=kCAGravityTop; rep("contentsGravity",L); };
  { L.contentsScale=2; rep("contentsScale",L); }; { L.contentsCenter=CGRectMake(.1,.1,.5,.5); rep("contentsCenter",L); }; { L.minificationFilter=kCAFilterNearest; rep("minificationFilter",L); };
  { L.magnificationFilter=kCAFilterNearest; rep("magnificationFilter",L); }; { L.opaque=YES; rep("opaque",L); }; { L.needsDisplayOnBoundsChange=YES; rep("needsDisplayOnBoundsChange",L); };
  { L.edgeAntialiasingMask=0; rep("edgeAntialiasingMask",L); }; { L.allowsEdgeAntialiasing=YES; rep("allowsEdgeAntialiasing",L); };
  { L.backgroundColor=CGColorCreateGenericRGB(0,0,1,1); rep("backgroundColor",L); }; { L.cornerRadius=5; rep("cornerRadius",L); }; { L.maskedCorners=3; rep("maskedCorners",L); }; { L.cornerCurve=kCACornerCurveContinuous; rep("cornerCurve",L); };
  { L.borderWidth=2; rep("borderWidth",L); }; { L.borderColor=CGColorCreateGenericRGB(0,1,0,1); rep("borderColor",L); }; { L.opacity=0.3; rep("opacity",L); }; { L.allowsGroupOpacity=NO; rep("allowsGroupOpacity",L); };
  { L.compositingFilter=@"multiplyBlendMode"; rep("compositingFilter",L); }; { L.filters=@[]; rep("filters",L); }; { L.backgroundFilters=@[]; rep("backgroundFilters",L); };
  { L.shouldRasterize=YES; rep("shouldRasterize",L); }; { L.rasterizationScale=2; rep("rasterizationScale",L); }; { L.shadowColor=CGColorCreateGenericRGB(1,0,0,1); rep("shadowColor",L); };
  { L.shadowOpacity=0.5; rep("shadowOpacity",L); }; { L.shadowOffset=CGSizeMake(3,3); rep("shadowOffset",L); }; { L.shadowRadius=9; rep("shadowRadius",L); };
  CGMutablePathRef pp=CGPathCreateMutable(); CGPathAddRect(pp,NULL,CGRectMake(0,0,10,10)); { L.shadowPath=pp; rep("shadowPath",L); };
  { L.autoresizingMask=3; rep("autoresizingMask",L); }; { L.name=@"n"; rep("name",L); }; { L.style=@{}; rep("style",L); }; { L.speed=3; rep("speed",L); }; { L.timeOffset=1; rep("timeOffset",L); }; { L.repeatCount=2; rep("repeatCount",L); };
  { L.wantsExtendedDynamicRangeContent=YES; rep("wantsEDRContent",L); }; { L.contentsFormat=kCAContentsFormatRGBA16Float; rep("contentsFormat",L); };
  CALayer *s1=[CALayer layer]; { [L addSublayer:s1]; rep("addSublayer",L); }; { [L insertSublayer:[CALayer layer] atIndex:0]; rep("insertSublayer",L); }; { [s1 removeFromSuperlayer]; rep("removeFromSuperlayer",L); };
  { L.sublayers=@[[CALayer layer]]; rep("setSublayers",L); }; { [L setNeedsDisplay]; rep("setNeedsDisplay",L); }; { [L setNeedsLayout]; rep("setNeedsLayout",L); };
  S=[CAShapeLayer layer]; S.frame=CGRectMake(0,0,50,50); ctx(S); [S removeAllAnimations];
  { S.path=pp; rep("shape.path",S); }; { S.fillColor=CGColorCreateGenericRGB(1,0,0,1); rep("shape.fillColor",S); }; { S.fillColor=CGColorCreateGenericRGB(0,1,0,1); rep("shape.fillColor2",S); }; { S.strokeColor=CGColorCreateGenericRGB(1,0,0,1); rep("shape.strokeColor",S); };
  { S.strokeEnd=0.5; rep("shape.strokeEnd",S); }; { S.strokeStart=0.2; rep("shape.strokeStart",S); }; { S.lineWidth=3; rep("shape.lineWidth",S); }; { S.miterLimit=3; rep("shape.miterLimit",S); }; { S.lineDashPhase=3; rep("shape.lineDashPhase",S); };
  { S.fillRule=kCAFillRuleEvenOdd; rep("shape.fillRule",S); }; { S.lineCap=kCALineCapRound; rep("shape.lineCap",S); }; { S.lineJoin=kCALineJoinRound; rep("shape.lineJoin",S); }; { S.lineDashPattern=@[@2,@3]; rep("shape.lineDashPattern",S); };
  G=[CAGradientLayer layer]; G.frame=CGRectMake(0,0,50,50); ctx(G); [G removeAllAnimations];
  { G.colors=@[(__bridge id)CGColorCreateGenericRGB(1,0,0,1),(__bridge id)CGColorCreateGenericRGB(0,0,1,1)]; rep("grad.colors",G); }; { G.locations=@[@0,@1]; rep("grad.locations",G); }; { G.locations=@[@0.2,@0.8]; rep("grad.locations2",G); };
  { G.startPoint=CGPointMake(0,0); rep("grad.startPoint",G); }; { G.endPoint=CGPointMake(1,0); rep("grad.endPoint",G); }; { G.type=kCAGradientLayerRadial; rep("grad.type",G); };
  T=[CATextLayer layer]; T.frame=CGRectMake(0,0,50,50); ctx(T); [T removeAllAnimations];
  { T.string=@"hi"; rep("text.string",T); }; { T.fontSize=20; rep("text.fontSize",T); }; { T.foregroundColor=CGColorCreateGenericRGB(1,0,0,1); rep("text.foregroundColor",T); }; { T.wrapped=YES; rep("text.wrapped",T); }; { T.alignmentMode=kCAAlignmentCenter; rep("text.align",T); };
  RP=[CAReplicatorLayer layer]; RP.frame=CGRectMake(0,0,50,50); ctx(RP); [RP removeAllAnimations];
  { RP.instanceCount=3; rep("rep.instanceCount",RP); }; { RP.instanceDelay=0.1; rep("rep.instanceDelay",RP); }; { RP.instanceTransform=CATransform3DMakeTranslation(5,0,0); rep("rep.instanceTransform",RP); }; { RP.instanceColor=CGColorCreateGenericRGB(1,1,1,1); rep("rep.instanceColor",RP); }; { RP.instanceRedOffset=0.1; rep("rep.instanceRedOffset",RP); };
}return 0;}
