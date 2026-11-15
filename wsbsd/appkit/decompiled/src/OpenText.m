/* OpenText.m — NSTextView on the REAL text system of the cache (UIFoundation: NSTextStorage, NSLayoutManager, NSTextContainer): layout, glyph drawing, hit testing come from there;
 * here: the selection, the caret, typing, the mouse.  The objects are kept with the view. */
#import <Foundation/Foundation.h>
#import <CoreGraphics/CoreGraphics.h>
#import <objc/runtime.h>
#import <objc/message.h>
#import "NSColor.h"
#import "NSGraphicsContext.h"
#import "NSEvent.h"
#import "NSWindow.h"
#import "NSView.h"
#import "NSTextView.h"
#import "NSApplication.h"
#import "NSFont.h"
#import "OpenBackend.h"

#define SEL_(s) sel_registerName(s)
typedef id (*ID0)(id, SEL);
typedef id (*ID1)(id, SEL, id);
typedef void (*V1)(id, SEL, id);
typedef NSUInteger (*U0)(id, SEL);
typedef void (*VR)(id, SEL, NSRange, id);
typedef CGRect (*RectFn)(id, SEL, ...);
typedef CGPoint (*PtFn)(id, SEL, ...);
typedef NSRange (*RangeFn)(id, SEL, ...);

@interface OpenTV : NSObject { @public id ts, lm, tc, tlm; id typing; NSRange sel; NSUInteger anchor; CGFloat off; } @end
@implementation OpenTV @end
static char kTV;
static const CGFloat kInsetX = 5, kInsetY = 4;

static OpenTV *TV(NSTextView *v)
{
    OpenTV *o = objc_getAssociatedObject(v, &kTV);
    if (o) return o;
    o = [OpenTV new]; o->sel = NSMakeRange(0, 0);
    id c = [v textContainer];
    id tlm = c ? ((ID0)objc_msgSend)(c, SEL_("textLayoutManager")) : nil, lm = c ? ((ID0)objc_msgSend)(c, SEL_("layoutManager")) : nil;
    if (tlm) {			/* TextKit 2 stack of the program: layout fragments, drawn by them */
        o->tc = c; o->tlm = tlm; id cm = ((ID0)objc_msgSend)(tlm, SEL_("textContentManager"));
        o->ts = [cm respondsToSelector:SEL_("textStorage")] ? ((ID0)objc_msgSend)(cm, SEL_("textStorage")) : nil;
    } else if (lm) { o->tc = c; o->lm = lm; o->ts = ((ID0)objc_msgSend)(lm, SEL_("textStorage")); }
    if (!o->ts && !o->tlm) {		/* nothing attached: our own TextKit 1 stack on the container of the view */
        o->ts = ((ID1)objc_msgSend)(((ID0)objc_msgSend)((id)objc_getClass("NSTextStorage"), SEL_("alloc")), SEL_("initWithString:"), @"");
        o->lm = ((ID0)objc_msgSend)(((ID0)objc_msgSend)((id)objc_getClass("NSLayoutManager"), SEL_("alloc")), SEL_("init"));
        if (!c) { CGSize sz = CGSizeMake([v bounds].size.width - 2 * kInsetX, 1e7); c = ((id(*)(id, SEL, CGSize))objc_msgSend)(((ID0)objc_msgSend)((id)objc_getClass("NSTextContainer"), SEL_("alloc")), SEL_("initWithSize:"), sz); }
        o->tc = c;
        ((V1)objc_msgSend)(o->lm, SEL_("addTextContainer:"), o->tc);
        ((V1)objc_msgSend)(o->ts, SEL_("addLayoutManager:"), o->lm);
    }
    objc_setAssociatedObject(v, &kTV, o, OBJC_ASSOCIATION_RETAIN);
    return o;
}
static NSUInteger Len(OpenTV *o) { return ((U0)objc_msgSend)(o->ts, SEL_("length")); }
static NSString *Str(OpenTV *o) { return ((ID0)objc_msgSend)(o->ts, SEL_("string")); }
static NSDictionary *Attrs(void) { return @{ NSFontAttributeName: [NSFont systemFontOfSize:13], NSForegroundColorAttributeName: [NSColor colorWithCalibratedWhite:1 alpha:0.85] }; }

@implementation NSTextView (OpenText)
- (BOOL)isFlipped { return YES; }
- (BOOL)acceptsFirstResponder { return YES; }
- (NSString *)string { return Str(TV(self)); }
- (void)setString:(NSString *)s
{
    OpenTV *o = TV(self);
    id as = ((id(*)(id, SEL, id, id))objc_msgSend)(((ID0)objc_msgSend)((id)objc_getClass("NSAttributedString"), SEL_("alloc")), SEL_("initWithString:attributes:"), s ?: @"", Attrs());
    ((void(*)(id, SEL, NSRange, id))objc_msgSend)(o->ts, SEL_("replaceCharactersInRange:withAttributedString:"), NSMakeRange(0, Len(o)), as);
    o->sel = NSMakeRange(Len(o), 0); o->anchor = o->sel.location;
    [self display];
}
- (NSRange)selectedRange { return TV(self)->sel; }
- (void)setSelectedRanges:(NSArray *)r { OpenTV *o = TV(self); NSRange x = [[r firstObject] rangeValue]; o->sel = x; o->anchor = x.location; }
- (NSArray *)selectedRanges { return @[[NSValue valueWithRange:TV(self)->sel]]; }
- (id)textStorage { return TV(self)->ts; }
- (id)layoutManager { return TV(self)->lm; }
- (id)textLayoutManager { return TV(self)->tlm; }
- (NSDictionary *)typingAttributes { return TV(self)->typing ?: Attrs(); }
- (void)setTypingAttributes:(NSDictionary *)a { TV(self)->typing = a; }
- (void)setSelectedRange:(NSRange)r { OpenTV *o = TV(self); o->sel = r; o->anchor = r.location; [self display]; }

- (void)drawRect:(CGRect)dirty
{
    CGContextRef cg = [[NSGraphicsContext currentContext] CGContext]; if (!cg) return;
    OpenTV *o = TV(self); CGRect b = [self bounds];
    CGContextSetRGBFillColor(cg, 23 / 255.0, 24 / 255.0, 25 / 255.0, 1); CGContextFillRect(cg, b);
    CGContextSaveGState(cg); CGContextClipToRect(cg, b); CGContextTranslateCTM(cg, 0, -o->off);
    CGSize sz = CGSizeMake(b.size.width - 2 * kInsetX, 1e7);
    if (!o->tlm) ((void(*)(id, SEL, CGSize))objc_msgSend)(o->tc, SEL_("setSize:"), sz);
    CGPoint org = CGPointMake(kInsetX, kInsetY);
    if (o->tlm) {			/* TextKit 2: every layout fragment draws itself */
        id cm = ((ID0)objc_msgSend)(o->tlm, SEL_("textContentManager")); id dr = ((ID0)objc_msgSend)(cm, SEL_("documentRange")); id loc = ((ID0)objc_msgSend)(dr, SEL_("location"));
        CGContextTranslateCTM(cg, org.x, org.y);
        BOOL (^blk)(id) = ^BOOL(id frag) { CGRect fr = ((RectFn)objc_msgSend_stret)(frag, SEL_("layoutFragmentFrame")); if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: fragment %g,%g %gx%g\n", fr.origin.x, fr.origin.y, fr.size.width, fr.size.height); ((void(*)(id, SEL, CGPoint, CGContextRef))objc_msgSend)(frag, SEL_("drawAtPoint:inContext:"), fr.origin, cg); return YES; };
        ((id(*)(id, SEL, id, NSUInteger, id))objc_msgSend)(o->tlm, SEL_("enumerateTextLayoutFragmentsFromLocation:options:usingBlock:"), loc, 2 /* ensures layout */, blk);
        CGContextRestoreGState(cg); return;
    }
    NSRange gr = ((RangeFn)objc_msgSend)(o->lm, SEL_("glyphRangeForTextContainer:"), o->tc);
    if (o->sel.length) {		/* the selection: one rectangle per line */
        NSUInteger n = 0;
        CGRect *rects = ((CGRect *(*)(id, SEL, NSRange, NSRange, id, NSUInteger *))objc_msgSend)(o->lm, SEL_("rectArrayForCharacterRange:withinSelectedCharacterRange:inTextContainer:rectCount:"), o->sel, NSMakeRange(NSNotFound, 0), o->tc, &n);
        CGContextSetRGBFillColor(cg, 63 / 255.0, 96 / 255.0, 130 / 255.0, 1);
        for (NSUInteger i = 0; rects && i < n; i++) CGContextFillRect(cg, CGRectOffset(rects[i], org.x, org.y));
    }
    ((void(*)(id, SEL, NSRange, CGPoint))objc_msgSend)(o->lm, SEL_("drawGlyphsForGlyphRange:atPoint:"), gr, org);
    if ([[self window] firstResponder] == self && !o->sel.length) {		/* the caret */
        CGRect c = [self _openCaretRect];
        CGContextSetRGBFillColor(cg, 0.3, 0.6, 1, 1); CGContextFillRect(cg, c);
    }
    CGContextRestoreGState(cg);
    CGFloat ch = [self _openContentHeight], vh = b.size.height;		/* scroller: a thin thumb on the right */
    if (ch > vh) { CGFloat th = vh * vh / ch, ty = (vh - th) * (o->off / (ch - vh)); CGContextSetRGBFillColor(cg, 1, 1, 1, 0.3); CGPathRef sp = CGPathCreateWithRoundedRect(CGRectMake(b.size.width - 8, ty + 2, 5, th - 4), 2.5, 2.5, NULL); CGContextAddPath(cg, sp); CGContextFillPath(cg); CGPathRelease(sp); }
}
- (CGFloat)_openContentHeight
{
    OpenTV *o = TV(self); if (!o->lm) return [self bounds].size.height;
    ((void(*)(id, SEL, CGSize))objc_msgSend)(o->tc, SEL_("setSize:"), CGSizeMake([self bounds].size.width - 2 * kInsetX, 1e7));
    CGRect u = ((RectFn)objc_msgSend_stret)(o->lm, SEL_("usedRectForTextContainer:"), o->tc);
    return u.size.height + 2 * kInsetY;
}
- (void)_openScrollBy:(NSNumber *)dy
{
    OpenTV *o = TV(self); CGFloat max = [self _openContentHeight] - [self bounds].size.height; if (max < 0) max = 0;
    CGFloat n = o->off - [dy doubleValue]; if (n < 0) n = 0; if (n > max) n = max;
    if (n != o->off) { o->off = n; [self display]; }
}
- (CGRect)_openCaretRect
{
    OpenTV *o = TV(self); NSUInteger ci = o->sel.location, len = Len(o);
    if (len == 0 || ci == 0 && len == 0) return CGRectMake(kInsetX, kInsetY, 1.5, 15);
    NSUInteger gi = ((NSUInteger(*)(id, SEL, NSUInteger))objc_msgSend)(o->lm, SEL_("glyphIndexForCharacterAtIndex:"), ci < len ? ci : len - 1);
    NSRange eff;
    CGRect lf = ((RectFn)objc_msgSend_stret)(o->lm, SEL_("lineFragmentRectForGlyphAtIndex:effectiveRange:"), gi, &eff);
    CGPoint loc = ((PtFn)objc_msgSend)(o->lm, SEL_("locationForGlyphAtIndex:"), gi);
    CGFloat x = lf.origin.x + loc.x;
    if (ci >= len) {		/* after the last character: right edge of the last glyph, or the start of a new line after a newline */
        CGRect gb = ((RectFn)objc_msgSend_stret)(o->lm, SEL_("boundingRectForGlyphRange:inTextContainer:"), NSMakeRange(gi, 1), o->tc);
        if ([Str(o) characterAtIndex:len - 1] == '\n') return CGRectMake(kInsetX, kInsetY + lf.origin.y + lf.size.height, 1.5, lf.size.height);
        x = gb.origin.x + gb.size.width;
    }
    return CGRectMake(kInsetX + x, kInsetY + lf.origin.y, 1.5, lf.size.height);
}
- (NSUInteger)_openIndexAt:(CGPoint)p
{
    OpenTV *o = TV(self); CGFloat frac = 0;
    CGPoint q = CGPointMake(p.x - kInsetX, p.y - kInsetY);
    return ((NSUInteger(*)(id, SEL, CGPoint, id, CGFloat *))objc_msgSend)(o->lm, SEL_("characterIndexForPoint:inTextContainer:fractionOfDistanceBetweenInsertionPoints:"), q, o->tc, &frac);
}
- (CGPoint)_openLocal:(NSEvent *)e
{
    CGPoint p = [e locationInWindow];
    for (NSView *v = self; v && v != [[self window] contentView]; v = [v superview]) { p.x -= [v frame].origin.x; p.y -= [v frame].origin.y; }
    CGRect cf = [[[self window] contentView] frame]; p.x -= cf.origin.x; p.y -= cf.origin.y;
    p.y = [self frame].size.height - p.y;			/* flipped */
    p.y += TV(self)->off;
    return p;
}
- (void)mouseDown:(NSEvent *)e
{
    [[self window] makeFirstResponder:self];
    OpenTV *o = TV(self); NSUInteger i = [self _openIndexAt:[self _openLocal:e]];
    if ([e modifierFlags] & NSEventModifierFlagShift) { NSUInteger a = o->anchor; o->sel = NSMakeRange(MIN(a, i), MAX(a, i) - MIN(a, i)); }
    else { o->anchor = i; o->sel = NSMakeRange(i, 0); }
    [self display];
}
- (void)mouseDragged:(NSEvent *)e
{
    OpenTV *o = TV(self); NSUInteger i = [self _openIndexAt:[self _openLocal:e]], a = o->anchor;
    o->sel = NSMakeRange(MIN(a, i), MAX(a, i) - MIN(a, i)); [self display];
}
- (void)_openReplace:(NSString *)s
{
    OpenTV *o = TV(self);
    id as = ((id(*)(id, SEL, id, id))objc_msgSend)(((ID0)objc_msgSend)((id)objc_getClass("NSAttributedString"), SEL_("alloc")), SEL_("initWithString:attributes:"), s, Attrs());
    ((void(*)(id, SEL, NSRange, id))objc_msgSend)(o->ts, SEL_("replaceCharactersInRange:withAttributedString:"), o->sel, as);
    o->sel = NSMakeRange(o->sel.location + [s length], 0); o->anchor = o->sel.location;
    [self display];
}
- (void)keyDown:(NSEvent *)e
{
    OpenTV *o = TV(self);
    if (getenv("OPEN_DEBUG")) fprintf(stderr, "open: textview keyDown %s ts=%p tlm=%p lm=%p len=%lu\n", [[e characters] UTF8String], (__bridge void *)o->ts, (__bridge void *)o->tlm, (__bridge void *)o->lm, (unsigned long)(o->ts ? Len(o) : 0)); NSString *c = [e characters]; unsigned short kc = [e keyCode]; NSUInteger len = Len(o);
    if (kc == 123 || kc == 124) {		/* left / right */
        NSUInteger p = o->sel.length ? (kc == 123 ? o->sel.location : o->sel.location + o->sel.length) : (kc == 123 ? (o->sel.location ? o->sel.location - 1 : 0) : MIN(o->sel.location + 1, len));
        o->sel = NSMakeRange(p, 0); o->anchor = p; [self display]; return;
    }
    if (kc == 125 || kc == 126) {		/* down / up: the point one line away */
        CGRect cr = [self _openCaretRect]; CGFloat lh = cr.size.height > 0 ? cr.size.height : 15;
        NSUInteger p = [self _openIndexAt:CGPointMake(cr.origin.x, cr.origin.y + (kc == 125 ? 1.5 * lh : -0.5 * lh))];
        o->sel = NSMakeRange(p, 0); o->anchor = p; [self display]; return;
    }
    if (kc == 51) {			/* delete */
        if (o->sel.length) [self _openReplace:@""]; else if (o->sel.location) { o->sel = NSMakeRange(o->sel.location - 1, 1); [self _openReplace:@""]; }
        return;
    }
    if ([c isEqualToString:@"\r"]) { [self _openReplace:@"\n"]; return; }
    if ([c length] && [c characterAtIndex:0] >= 32) [self _openReplace:c];
}
@end
