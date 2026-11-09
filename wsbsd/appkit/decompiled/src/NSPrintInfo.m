/*
 * NSPrintInfo.m — 1:1 (core). See NSPrintInfo.h for the interface evidence.
 *
 * Every property is backed by the attributes dictionary under its NSPrint* key.
 * A fresh instance seeds the AppKit defaults (US Letter 612x792, portrait,
 * scaling 1.0, 72pt margins, horizontally centered). sharedPrintInfo is the
 * process default. The print operation and the PMPrintSettings bridge are stage2.
 */
#import "NSPrintInfo.h"

static NSString * const kPaperName   = @"NSPaperName";
static NSString * const kPaperSize   = @"NSPaperSize";
static NSString * const kOrientation = @"NSOrientation";
static NSString * const kScaling     = @"NSScalingFactor";
static NSString * const kLeftMargin  = @"NSLeftMargin";
static NSString * const kRightMargin = @"NSRightMargin";
static NSString * const kTopMargin   = @"NSTopMargin";
static NSString * const kBottomMargin= @"NSBottomMargin";
static NSString * const kHCentered   = @"NSHorizonallyCentered";
static NSString * const kVCentered   = @"NSVerticallyCentered";

static NSPrintInfo *sSharedPrintInfo = nil;

@implementation NSPrintInfo {
    NSMutableDictionary<NSString *, id> *_attributes;
}

- (instancetype)initWithDictionary:(NSDictionary<NSString *, id> *)attributes
{
    self = [super init];
    if (self) {
        _attributes = [NSMutableDictionary dictionary];
        /* defaults */
        _attributes[kPaperName] = @"NSLetter";
        _attributes[kPaperSize] = [NSValue valueWithBytes:&(CGSize){612, 792} objCType:@encode(CGSize)];
        _attributes[kOrientation] = @(NSPaperOrientationPortrait);
        _attributes[kScaling] = @1.0;
        _attributes[kLeftMargin] = @72.0;
        _attributes[kRightMargin] = @72.0;
        _attributes[kTopMargin] = @72.0;
        _attributes[kBottomMargin] = @72.0;
        _attributes[kHCentered] = @YES;
        _attributes[kVCentered] = @NO;
        if (attributes) [_attributes addEntriesFromDictionary:attributes];
    }
    return self;
}

- (instancetype)init { return [self initWithDictionary:nil]; }

+ (NSPrintInfo *)sharedPrintInfo
{
    if (!sSharedPrintInfo) sSharedPrintInfo = [[NSPrintInfo alloc] init];
    return sSharedPrintInfo;
}
+ (void)setSharedPrintInfo:(NSPrintInfo *)info { sSharedPrintInfo = info; }

- (NSMutableDictionary<NSString *, id> *)dictionary { return _attributes; }

- (NSString *)paperName { return _attributes[kPaperName]; }
- (void)setPaperName:(NSString *)v { _attributes[kPaperName] = [v copy]; }

- (CGSize)paperSize { CGSize s = CGSizeZero; [_attributes[kPaperSize] getValue:&s]; return s; }
- (void)setPaperSize:(CGSize)v { _attributes[kPaperSize] = [NSValue valueWithBytes:&v objCType:@encode(CGSize)]; }

- (NSPaperOrientation)orientation { return [_attributes[kOrientation] integerValue]; }
- (void)setOrientation:(NSPaperOrientation)v { _attributes[kOrientation] = @(v); }
- (CGFloat)scalingFactor { return [_attributes[kScaling] doubleValue]; }
- (void)setScalingFactor:(CGFloat)v { _attributes[kScaling] = @(v); }
- (CGFloat)leftMargin { return [_attributes[kLeftMargin] doubleValue]; }
- (void)setLeftMargin:(CGFloat)v { _attributes[kLeftMargin] = @(v); }
- (CGFloat)rightMargin { return [_attributes[kRightMargin] doubleValue]; }
- (void)setRightMargin:(CGFloat)v { _attributes[kRightMargin] = @(v); }
- (CGFloat)topMargin { return [_attributes[kTopMargin] doubleValue]; }
- (void)setTopMargin:(CGFloat)v { _attributes[kTopMargin] = @(v); }
- (CGFloat)bottomMargin { return [_attributes[kBottomMargin] doubleValue]; }
- (void)setBottomMargin:(CGFloat)v { _attributes[kBottomMargin] = @(v); }
- (BOOL)isHorizontallyCentered { return [_attributes[kHCentered] boolValue]; }
- (void)setHorizontallyCentered:(BOOL)v { _attributes[kHCentered] = @(v); }
- (BOOL)isVerticallyCentered { return [_attributes[kVCentered] boolValue]; }
- (void)setVerticallyCentered:(BOOL)v { _attributes[kVCentered] = @(v); }

- (id)copyWithZone:(NSZone *)zone { return [[NSPrintInfo alloc] initWithDictionary:_attributes]; }

@end
