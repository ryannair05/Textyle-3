#import "TXTListController.h"
#import "TXTPreferences.h"
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
    NSString *domain = specifier.properties[@"defaults"];
    NSDictionary *prefs = [NSDictionary dictionaryWithContentsOfFile:
        [TXTPreferencesDirectory stringByAppendingPathComponent:
            [domain stringByAppendingPathExtension:@"plist"]]];

    return prefs[specifier.properties[@"key"]] ?:
        specifier.properties[@"default"];
}

- (void)setPreferenceValue:(id)value specifier:(PSSpecifier *)specifier {
    NSString *domain = specifier.properties[@"defaults"];
    NSString *path = [TXTPreferencesDirectory stringByAppendingPathComponent:
        [domain stringByAppendingPathExtension:@"plist"]];

    NSMutableDictionary *prefs =
        [NSMutableDictionary dictionaryWithContentsOfFile:path] ?:
        [NSMutableDictionary dictionary];
   
    [prefs setObject:value forKey:specifier.properties[@"key"]];
    [prefs writeToFile:path atomically:YES];

    if ([specifier.properties objectForKey:@"PostNotification"]) {
        CFNotificationCenterPostNotification(
            CFNotificationCenterGetDarwinNotifyCenter(),
            (__bridge CFStringRef)specifier.properties[@"PostNotification"],
            NULL,
            NULL,
            YES);
    }
}

@end
