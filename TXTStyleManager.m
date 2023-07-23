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

        if ([[NSFileManager defaultManager] fileExistsAtPath:kUserStylesPath]) {
            styles = [[NSArray alloc] initWithContentsOfFile:kUserStylesPath];
        } else {
            styles = [[NSArray alloc] initWithContentsOfFile:kEnabledStylesPath];
        }
        
        NSDictionary *preferences = [[NSDictionary alloc] initWithContentsOfFile:kEnabledStylesPath];

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
        NSMutableDictionary *prefs = [NSMutableDictionary dictionary];
        [prefs addEntriesFromDictionary:[NSDictionary dictionaryWithContentsOfFile:kPrefsPath]];

        [prefs setObject:self.activeStyle[@"name"] forKey:@"ActiveStyle"];
        [prefs writeToFile:kPrefsPath atomically:YES];
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
