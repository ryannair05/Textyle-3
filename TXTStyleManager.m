#import "TXTStyleManager.h"
#import "TXTConstants.h"
#import "NSString+Stylize.h"

@interface NSDistributedNotificationCenter : NSNotificationCenter
@end

@implementation TXTStyleManager

+ (instancetype)sharedManager {
    static TXTStyleManager *sharedManager;
    static dispatch_once_t onceToken;

    dispatch_once(&onceToken, ^{
        sharedManager = [[self alloc] init];
    });

    return sharedManager;
}

- (instancetype)init {
    self = [super init];

    if (self) {

        NSArray *styles;

        #ifdef THEOS_PACKAGE_INSTALL_PREFIX
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"]) {
            styles = [[NSArray alloc] initWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"];
        } else {
            styles = [[NSArray alloc] initWithContentsOfFile:@"/var/jb/Library/Application Support/Textyle/styles.plist"];
        }
        #else
        if ([[NSFileManager defaultManager] fileExistsAtPath:@"/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"]) {
            styles = [[NSArray alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.ryannair05.textyle.maps.plist"];
        } else {
            styles = [[NSArray alloc] initWithContentsOfFile:@"/Library/Application Support/Textyle/styles.plist"];
        }
        #endif

        #ifdef THEOS_PACKAGE_INSTALL_PREFIX
        NSDictionary *preferences = [[NSDictionary alloc] initWithContentsOfFile:@"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.styles.plist"];
        #else
        NSDictionary *preferences = [[NSDictionary alloc] initWithContentsOfFile:@"/var/mobile/Library/Preferences/com.ryannair05.textyle.styles.plist"];
        #endif

        if (preferences) {
            _enabledStyles = [styles filteredArrayUsingPredicate:[NSPredicate predicateWithBlock:^BOOL(id style, NSDictionary *bindings) {
                if ([preferences objectForKey:style[@"name"]] == nil) {
                    return YES;
                }

                return [[preferences objectForKey:style[@"name"]] boolValue];
            }]];
        } else {
            _enabledStyles = styles;
        }
        
        [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(loadActiveStyle:) name:@"TextyleStyleDidChange" object:nil];
    }

    return self;
}

- (void)loadActiveStyle:(NSNotification *)notification {
    self.activeStyle = [self styleWithName:notification.userInfo[@"ActiveStyle"]];

    CFStringRef const identifier = CFBundleGetIdentifier(CFBundleGetMainBundle());
    BOOL const isSpringBoard = CFEqual(identifier, CFSTR("com.apple.springboard"));

    if (isSpringBoard) {
        #ifdef THEOS_PACKAGE_INSTALL_PREFIX
        NSString *path = [NSString stringWithFormat:@"/var/jb/var/mobile/Library/Preferences/com.ryannair05.textyle.plist"];
        #else
        NSString *path = [NSString stringWithFormat:@"/var/mobile/Library/Preferences/com.ryannair05.textyle.plist"];
        #endif

        NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
        [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:path]];

        [prefs setObject:self.activeStyle[@"name"] forKey:@"ActiveStyle"];
        [prefs writeToFile:path atomically:YES];
    }
}

- (void)selectStyle:(NSString *)label {
    NSUInteger index = [_enabledStyles indexOfObjectPassingTest:^BOOL (NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        return [[dict objectForKey:@"label"] isEqualToString:label];
    }];
     
    self.activeStyle = [_enabledStyles objectAtIndex:index];

    [[NSDistributedNotificationCenter defaultCenter] postNotificationName:@"TextyleStyleDidChange" object:nil userInfo:@{@"ActiveStyle" : self.activeStyle[@"name"]}];
}

- (NSDictionary *)styleWithName:(NSString *)name {
    for (NSDictionary* object in self.enabledStyles) {
        if ([[object objectForKey:@"name"] isEqualToString:name]) {
            return object;
        }
    }

    return [_enabledStyles firstObject];
}

@end
