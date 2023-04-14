#import "TXTAppListController.h"

@implementation TXTAppListController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIColor *tintColor = [UIColor colorWithRed:1.00 green:0.18 blue:0.33 alpha:0.85f];
    [UISwitch appearanceWhenContainedInInstancesOfClasses:@[self.class]].onTintColor = tintColor;

    for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
        if (windowScene.activationState == UISceneActivationStateForegroundActive) {
            [[windowScene windows] firstObject].tintColor = tintColor;
            return;
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
        if (windowScene.activationState == UISceneActivationStateForegroundActive) {
            [[windowScene windows] firstObject].tintColor = nil;
            return;
        }
    }
}

@end
