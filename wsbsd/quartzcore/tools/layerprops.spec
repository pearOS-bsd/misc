# name  type  default  flags   [class]
# types: F float, D CGFloat, B BOOL, U unsigned, PT CGPoint, SZ CGSize, RC CGRect, TF CATransform3D, COL CGColorRef, PATH CGPathRef, OBJ id, STR NSString*, ARR NSArray*
# flags: A implicit basic animation, T implicit transition, X display (contents are redrawn), G geometry, N animated even from nil; C no accessor generated
@CALayer
bounds          RC   {0,0,0,0}                        A,G
position        PT   {0,0}                            A,G
zPosition       D    0                                A,G
anchorPoint     PT   {0.5,0.5}                        A,G
anchorPointZ    D    0                                A,G
transform       TF   IDENT                            A,G
sublayerTransform TF IDENT                            A,G
hidden          B    NO                               T
doubleSided     B    YES
geometryFlipped B    NO                               T
masksToBounds   B    NO                               T
opaque          B    NO
contents        OBJ  nil                              A,N
contentsRect    RC   {0,0,1,1}                        A
contentsGravity STR  @"resize"
contentsScale   D    1                                A
contentsCenter  RC   {0,0,1,1}                        A
contentsFormat  STR  @"RGBA8"
minificationFilter STR @"linear"
magnificationFilter STR @"linear"
minificationFilterBias F 0
needsDisplayOnBoundsChange B NO
drawsAsynchronously B NO
edgeAntialiasingMask U:CAEdgeAntialiasingMask 15
allowsEdgeAntialiasing B YES
backgroundColor COL  NULL                             A
cornerRadius    D    0                                A
maskedCorners   U:CACornerMask    15                               T
cornerCurve     STR  @"circular"
borderWidth     D    0                                A
borderColor     COL  BLACK                            A
opacity         F    1                                A
allowsGroupOpacity B YES
compositingFilter OBJ nil                             T
filters         ARR  nil                              T
backgroundFilters ARR nil                             T
shouldRasterize B    NO
rasterizationScale D 1
shadowColor     COL  BLACK                            A
shadowOpacity   F    0                                A
shadowOffset    SZ   {0,-3}                           A
shadowRadius    D    3                                A
shadowPath      PATH NULL
autoresizingMask U:CAAutoresizingMask   0
name            STR  nil
style           OBJ  nil
wantsExtendedDynamicRangeContent B NO
toneMapMode     STR  @"automatic"
preferredDynamicRange STR @"standard"
contentsHeadroom D   0
wantsDynamicContentScaling B NO
@CAShapeLayer
path            PATH NULL                             A,X
fillColor       COL  BLACK                            A,X
fillRule        STR  @"non-zero"                      X
strokeColor     COL  NULL                             A,X
strokeStart     D    0                                A,X
strokeEnd       D    1                                A,X
lineWidth       D    1                                A,X
miterLimit      D    10                               A,X
lineCap         STR  @"butt"                          X
lineJoin        STR  @"miter"                         X
lineDashPhase   D    0                                A,X
lineDashPattern ARR  nil                              X
@CATextLayer
string          OBJ  nil                              X
font            OBJ:CFTypeRef  nil                              X
fontSize        D    36                               A,X
foregroundColor COL  WHITE                            A,X
wrapped         B    NO                               X
truncationMode  STR  @"none"                          X
alignmentMode   STR  @"natural"                       X
allowsFontSubpixelQuantization B NO                   X
@CAGradientLayer
colors          ARR  nil                              A,X
locations       ARR  nil                              A,X
startPoint      PT   {0.5,0}                          A,X
endPoint        PT   {0.5,1}                          A,X
type            STR  @"axial"                         X
@CAReplicatorLayer
instanceCount   UL:NSInteger   1                                A
preservesDepth  B    NO
instanceDelay   D    0                                A
instanceTransform TF IDENT                            A
instanceColor   COL  WHITE                            A
instanceRedOffset F  0                                A
instanceGreenOffset F 0                               A
instanceBlueOffset F 0                                A
instanceAlphaOffset F 0                               A
@CAScrollLayer
scrollMode      STR  @"both"
@CATiledLayer
levelsOfDetail  UL   1
levelsOfDetailBias UL 0
tileSize        SZ   {256,256}
@CAEmitterLayer
emitterCells    ARR  nil                              X
birthRate       F    1                                A
lifetime        F    1                                A
emitterPosition PT   {0,0}                            A
emitterZPosition D   0                                A
emitterSize     SZ   {0,0}                            A
emitterDepth    D    0                                A
emitterShape    STR  @"point"
emitterMode     STR  @"volume"
renderMode      STR  @"unordered"
velocity        F    1                                A
scale           F    1                                A
spin            F    1                                A
seed            U    0
