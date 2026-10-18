/* Terminal profiles ("Window Settings"): the colours, font, blur and window size of the profiles that Terminal.app ships (values from tools/gen_profiles.py). */
#import <AppKit/AppKit.h>

@interface TermProfile : NSObject
{
@public
	NSString *name; NSColor *background, *text, *boldText, *cursor, *selection; NSString *fontName; CGFloat fontSize, widthSpacing, blur; int cols, rows; BOOL blink, antialias; uint32_t ansi[16];
}
+ (NSArray *)allProfiles;                                   /* in the order of the Settings menu */
+ (TermProfile *)profileNamed:(NSString *)name;
+ (TermProfile *)defaultProfile;                            /* the one "Use Settings as Default" last stored (NSUserDefaults "Default Window Settings"), else Pro */
+ (void)setDefaultProfile:(TermProfile *)p;
- (NSFont *)fontWithSize:(CGFloat)size bold:(BOOL)bold;
- (void)changed;                                            /* after an edit: stores the profile's values in the user defaults and tells every terminal that uses it (TermProfileChanged) */
@end
