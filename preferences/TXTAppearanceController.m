#import "TXTAppearanceController.h"

@implementation TXTAppearanceController

- (NSArray *)specifiers {
    if (!_specifiers) {
        _specifiers = [self loadSpecifiersFromPlistName:@"Appearance" target:self];
    }

    return _specifiers;
}

@end
