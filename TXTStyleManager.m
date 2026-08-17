#import "TXTStyleManager.h"
#import "TXTConstants.h"
#import "Tweak.h"

NSNotificationName const TXTActiveStyleDidChangeNotification =
    @"TXTActiveStyleDidChangeNotification";

@interface TXTStyleManager ()
@property (nonatomic, strong, readwrite, nullable) NSDictionary *activeStyle;
@property (nonatomic, copy, readwrite) NSArray<NSDictionary *> *enabledStyles;
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
        NSArray *styles = [NSArray arrayWithContentsOfFile:kUserStylesPath];
        if (![styles isKindOfClass:[NSArray class]] || styles.count == 0) {
            styles = [NSArray arrayWithContentsOfFile:kSystemStylesPath];
        }
        if (![styles isKindOfClass:[NSArray class]]) {
            styles = @[];
        }

        NSDictionary *enabledPreferences =
            [NSDictionary dictionaryWithContentsOfFile:kEnabledStylesPath];
        if (![enabledPreferences isKindOfClass:[NSDictionary class]]) {
            enabledPreferences = @{};
        }

        NSMutableArray<NSDictionary *> *enabled = [NSMutableArray array];
        NSMutableSet<NSString *> *seenNames = [NSMutableSet set];
        for (id candidate in styles) {
            if (![candidate isKindOfClass:[NSDictionary class]]) {
                continue;
            }

            NSDictionary *style = (NSDictionary *)candidate;
            NSString *name = style[@"name"];
            NSString *label = style[@"label"];
            if (![name isKindOfClass:[NSString class]] || name.length == 0 ||
                ![label isKindOfClass:[NSString class]] || label.length == 0 ||
                [seenNames containsObject:name]) {
                continue;
            }
            [seenNames addObject:name];

            id enabledValue = enabledPreferences[name];
            if (enabledValue == nil || [enabledValue boolValue]) {
                [enabled addObject:style];
            }
        }

        _enabledStyles = [enabled copy];
        _activeStyle = TXTActiveStyleName.length > 0
            ? [self styleWithName:TXTActiveStyleName]
            : nil;
        _activeStyle = _activeStyle ?: _enabledStyles.firstObject;
        TXTActiveStyleName = [_activeStyle[@"name"] copy];

        [[NSDistributedNotificationCenter defaultCenter]
            addObserver:self
               selector:@selector(activeStyleDidChange:)
                   name:TXTStyleDidChangeDistributedNotification
                 object:nil];
    }
    return self;
}

- (void)activeStyleDidChange:(NSNotification *)notification {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self activeStyleDidChange:notification];
        });
        return;
    }

    NSString *name = notification.userInfo[@"ActiveStyle"];
    NSDictionary *style = [self styleWithName:name];
    if (style == nil) {
        return;
    }

    if ([self.activeStyle[@"name"] isEqualToString:style[@"name"]]) {
        return;
    }

    self.activeStyle = style;
    TXTActiveStyleName = [style[@"name"] copy];
    TXTLiveStateGeneration += 1;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TXTActiveStyleDidChangeNotification
                      object:self];

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject][CrossProcess] style received process=%@ style=%@ live=%@",
          NSProcessInfo.processInfo.processName,
          style[@"name"],
          TXTLiveTypingActive ? @"YES" : @"NO");
#endif
}

- (void)selectStyle:(NSString *)name {
    NSDictionary *selectedStyle = [self styleWithName:name];
    if (selectedStyle == nil) {
        return;
    }

    self.activeStyle = selectedStyle;
    TXTActiveStyleName = [selectedStyle[@"name"] copy];
    TXTLiveStateGeneration += 1;
    [[NSNotificationCenter defaultCenter]
        postNotificationName:TXTActiveStyleDidChangeNotification
                      object:self];
    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:TXTStyleDidChangeDistributedNotification
                      object:nil
                    userInfo:@{@"ActiveStyle": selectedStyle[@"name"]}];

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject][CrossProcess] style sent process=%@ style=%@ live=%@",
          NSProcessInfo.processInfo.processName,
          selectedStyle[@"name"],
          TXTLiveTypingActive ? @"YES" : @"NO");
#endif
}

- (NSDictionary *)styleWithName:(NSString *)name {
    for (NSDictionary *style in self.enabledStyles) {
        if ([style[@"name"] isEqualToString:name]) {
            return style;
        }
    }
    return nil;
}

@end
