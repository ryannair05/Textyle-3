#import "TXTListController.h"
#import <Preferences/PSSpecifier.h>

@implementation TXTListController

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];

    UIColor *tintColor = [UIColor colorWithRed:1.00 green:0.18 blue:0.33 alpha:0.85f];

    [UISwitch appearanceWhenContainedInInstancesOfClasses:@[self.class]].onTintColor = tintColor;

    for (UIWindowScene *windowScene in [UIApplication sharedApplication].connectedScenes) {
        if (windowScene.activationState == UISceneActivationStateForegroundActive) {
            settingsView = [[windowScene windows] firstObject];
            settingsView.tintColor = tintColor;
            return;
        }
    }
}

- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];

    settingsView.tintColor = nil;
}

- (id)readPreferenceValue:(PSSpecifier *)specifier {
    #ifdef THEOS_PACKAGE_INSTALL_PREFIX
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/var/jb/User/Library/Preferences/%@.plist", [specifier.properties objectForKey:@"defaults"]]];
    #else
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:[NSString stringWithFormat:@"/User/Library/Preferences/%@.plist", [specifier.properties objectForKey:@"defaults"]]];
    #endif

    if (![prefs objectForKey:[specifier.properties objectForKey:@"key"]]) {
        return [specifier.properties objectForKey:@"default"];
    }

    return [prefs objectForKey:[specifier.properties objectForKey:@"key"]];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {

    #ifdef THEOS_PACKAGE_INSTALL_PREFIX
    NSString *path = [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    #else
    NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/%@.plist", specifier.properties[@"defaults"]];
    #endif

    NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
    [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];
   
    [prefs setObject:value forKey:specifier.properties[@"key"]];
    [prefs writeToFile:path atomically:YES];

    if ([specifier.properties objectForKey:@"PostNotification"]) {
        CFNotificationCenterPostNotification(CFNotificationCenterGetDarwinNotifyCenter(), (CFStringRef)[specifier.properties objectForKey:@"PostNotification"], NULL, NULL, YES);
    }
}

@end
