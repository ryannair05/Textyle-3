#import "Tweak.h"

#import "NSString+Stylize.h"
#import "UIKitPrivate.h"
#import "TXTConstants.h"
#import "TXTStyleManager.h"
#import "TXTTextInput.h"

#import <UIKit/UIKit.h>
#import <crt_externs.h>
#import <objc/runtime.h>
#import <string.h>
#import <unistd.h>

#if defined(TEXTYLE_SIMJECT)
#import "Simulator/TXTSimulatorSelfTests.h"
#endif

NSNotificationName const TXTLiveStateDidChangeNotification =
    @"TXTLiveStateDidChangeNotification";
NSString * const TXTStyleDidChangeDistributedNotification =
    @"TextyleStyleDidChange";
NSString * const TXTDockModeDidChangeDistributedNotification =
    @"TextyleDockModeDidChange";

BOOL TXTLiveTypingActive = NO;
BOOL TXTDockUsesTextyle = YES;
NSString *TXTActiveStyleName = nil;
NSUInteger TXTLiveStateGeneration = 0;

UIImage *resizeImage(UIImage *image, CGSize size) {
    if (image == nil) {
        return nil;
    }

    UIGraphicsImageRenderer *renderer =
        [[UIGraphicsImageRenderer alloc] initWithSize:size];
    return [renderer imageWithActions:^(UIGraphicsImageRendererContext *context) {
        [image drawInRect:(CGRect){CGPointZero, size}];
    }];
}

static BOOL TXTPreferenceBool(NSDictionary *preferences,
                              NSString *key,
                              BOOL defaultValue) {
    id value = preferences[key];
    return value == nil ? defaultValue : [value boolValue];
}

void TXTSetLiveTypingActive(BOOL active) {
    if (TXTLiveTypingActive != active) {
        TXTLiveTypingActive = active;
        TXTLiveStateGeneration += 1;
        [[NSNotificationCenter defaultCenter] postNotificationName:TXTLiveStateDidChangeNotification object:nil];
    }
}

void TXTSetDockUsesTextyleAndBroadcast(BOOL usesTextyle) {
    if (TXTDockUsesTextyle != usesTextyle) {
        TXTDockUsesTextyle = usesTextyle;
        [[NSNotificationCenter defaultCenter] postNotificationName:TXTLiveStateDidChangeNotification object:nil];
    }

    [[NSDistributedNotificationCenter defaultCenter]
        postNotificationName:TXTDockModeDidChangeDistributedNotification
                      object:nil
                    userInfo:@{@"DockUsesTextyle": @(usesTextyle)}];

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject][CrossProcess] dock sent process=%@ uses-textyle=%@ live=%@",
          NSProcessInfo.processInfo.processName,
          usesTextyle ? @"YES" : @"NO",
          TXTLiveTypingActive ? @"YES" : @"NO");
#endif
}

@interface TXTDistributedStateObserver : NSObject
@end

@implementation TXTDistributedStateObserver

- (void)dockModeDidChange:(NSNotification *)notification {
    if (!NSThread.isMainThread) {
        dispatch_async(dispatch_get_main_queue(), ^{
            [self dockModeDidChange:notification];
        });
        return;
    }

    id value = notification.userInfo[@"DockUsesTextyle"];
    if (value == nil) {
        return;
    }

    BOOL usesTextyle = [value boolValue];
    if (TXTDockUsesTextyle != usesTextyle) {
        TXTDockUsesTextyle = usesTextyle;
        [[NSNotificationCenter defaultCenter] postNotificationName:TXTLiveStateDidChangeNotification object:nil];
    }

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject][CrossProcess] dock received process=%@ uses-textyle=%@ live=%@",
          NSProcessInfo.processInfo.processName,
          usesTextyle ? @"YES" : @"NO",
          TXTLiveTypingActive ? @"YES" : @"NO");
#endif
}

@end

#pragma mark - iOS 15 Legacy Callout Menu

@interface UICalloutBar : UIView
@property (nonatomic, retain) NSArray *extraItems;
@property (nonatomic, retain) UIMenuItem *txtMainMenuItem;
@property (nonatomic, retain) NSArray<UIMenuItem *> *txtStyleMenuItems;
+ (instancetype)sharedCalloutBar;
- (void)update;
- (void)resetPage;
@end

@interface UICalloutBarButton : UIButton
@property (nonatomic, assign) SEL action;
- (void)setupWithTitle:(id)title action:(SEL)action type:(int)type;
- (void)setupWithImage:(id)image action:(SEL)action type:(int)type;
@end

@interface UIMenuItem (TXTLegacyPrivate)
@property (nonatomic, assign) BOOL dontDismiss;
@end

@interface UIResponder (TXTLegacyMenu)
- (void)txtOpenStyleMenu:(nullable id)sender;
- (void)txtDidSelectStyle:(NSString *)name;
@end

static BOOL TXTLegacyMenuOpen = NO;
static NSString *TXTLegacyMenuTitle = @"Textyle";

/* UIImage file loading reaches UIScreen, which is not ready during dylib init. */
static UIImage *TXTLegacyMenuImageTemplate(void) {
    static UIImage *image;
    if (image == nil) {
        image = [resizeImage([UIImage imageWithContentsOfFile:kMenuIcon],
                             CGSizeMake(18.0, 18.0))
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return image;
}

static UIImage *TXTLegacyMenuImageTinted(void) {
    static UIImage *image;
    if (image == nil) {
        image = [[resizeImage([UIImage imageWithContentsOfFile:kMenuIcon],
                              CGSizeMake(18.0, 18.0))
            imageWithTintColor:kAccentColor]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return image;
}

static UIImage *(*TXTLegacyMenuImageProvider)(void) = TXTLegacyMenuImageTemplate;

static id TXTLegacyObjectIvar(id object, const char *name) {
    Ivar ivar = class_getInstanceVariable(object_getClass(object), name);
    return ivar == NULL ? nil : object_getIvar(object, ivar);
}

static NSArray<UIMenuItem *> *TXTLegacyStyleMenuItems(void) {
    NSMutableArray<UIMenuItem *> *items = [NSMutableArray array];
    for (NSDictionary *style in TXTStyleManager.sharedManager.enabledStyles) {
        NSString *name = style[@"name"];
        NSString *label = style[@"label"];
        SEL action = NSSelectorFromString([@"txt_" stringByAppendingString:name]);
        [items addObject:[[UIMenuItem alloc] initWithTitle:label action:action]];
    }

    return items;
}

static NSString *TXTLegacyStyleNameForSelector(SEL selector) {
    NSString *selectorName = NSStringFromSelector(selector);
    if (![selectorName hasPrefix:@"txt_"]) {
        return nil;
    }

    NSString *styleName = [selectorName substringFromIndex:4];
    return [TXTStyleManager.sharedManager styleWithName:styleName] == nil
        ? nil
        : styleName;
}

%group TXTLegacyCalloutMenu

%hook UICalloutBar

%property (nonatomic, retain) UIMenuItem *txtMainMenuItem;
%property (nonatomic, retain) NSArray *txtStyleMenuItems;

- (id)initWithFrame:(CGRect)frame {
    self = %orig;
    self.txtMainMenuItem = [[UIMenuItem alloc] initWithTitle:TXTLegacyMenuTitle
                                                     action:@selector(txtOpenStyleMenu:)];
    self.txtMainMenuItem.dontDismiss = YES;
    self.txtStyleMenuItems = TXTLegacyStyleMenuItems();
    return self;
}

- (void)updateAvailableButtons {
    %orig;

    NSMutableArray<UICalloutBarButton *> *systemButtons =
        TXTLegacyObjectIvar(self, "m_currentSystemButtons");
    BOOL hasSelection = NO;
    for (UICalloutBarButton *button in systemButtons) {
        if (button.action == @selector(cut:)) {
            hasSelection = YES;
            break;
        }
    }

    self.txtStyleMenuItems = TXTLegacyStyleMenuItems();
    NSMutableArray<UIMenuItem *> *items =
        [self.extraItems mutableCopy] ?: [NSMutableArray array];

    /* Remove actions generated by an earlier rebuild before adding fresh ones. */
    NSIndexSet *staleStyleIndexes = [items indexesOfObjectsPassingTest:
        ^BOOL(UIMenuItem *item, NSUInteger index, BOOL *stop) {
        return item != self.txtMainMenuItem &&
               [NSStringFromSelector(item.action) hasPrefix:@"txt_"];
    }];
    [items removeObjectsAtIndexes:staleStyleIndexes];

    if (hasSelection && !TXTLegacyMenuOpen) {
        if (![items containsObject:self.txtMainMenuItem]) {
            [items addObject:self.txtMainMenuItem];
        }
    } else {
        [items removeObject:self.txtMainMenuItem];
    }

    if (TXTLegacyMenuOpen) {
        items = [self.txtStyleMenuItems mutableCopy];
    }

    self.extraItems = items;
    %orig;

    if (TXTLegacyMenuOpen) {
        /* The second UIKit rebuild can replace this ivar, so reacquire it. */
        systemButtons = TXTLegacyObjectIvar(self, "m_currentSystemButtons");
        for (UICalloutBarButton *button in [systemButtons copy]) {
            [button removeFromSuperview];
        }
        [systemButtons removeAllObjects];
    }
}

%end

%hook UIResponder

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (TXTLegacyMenuOpen) {
        return TXTLegacyStyleNameForSelector(action) != nil;
    }
    if (action == @selector(txtOpenStyleMenu:)) {
        return TXTReadSelectedText(TXTResolveTextInput(self), NULL, NULL);
    }

    return %orig;
}

%new
- (void)txtOpenStyleMenu:(id)sender {
    TXTLegacyMenuOpen = YES;
    UICalloutBar *calloutBar = UICalloutBar.sharedCalloutBar;
    [calloutBar resetPage];
    [calloutBar update];
}

%new
- (void)txtDidSelectStyle:(NSString *)name {
    TXTLegacyMenuOpen = NO;

    UIResponder<UITextInput> *textInput = TXTResolveTextInput(self);
    UITextRange *selection = nil;
    NSString *selectedText = nil;
    if (!TXTReadSelectedText(textInput, &selection, &selectedText)) {
        return;
    }

    NSDictionary *style = [TXTStyleManager.sharedManager styleWithName:name];
    if (style == nil) {
        return;
    }

    NSString *replacement = [NSString stylizeText:selectedText withStyle:style];
    if (replacement != nil) {
        [textInput replaceRange:selection withText:replacement];
    }
}

%end

%hook UITextField

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = %orig(selector);
    if (signature == nil && TXTLegacyStyleNameForSelector(selector) != nil) {
        signature = %orig(@selector(txtDidSelectStyle:));
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *styleName = TXTLegacyStyleNameForSelector(invocation.selector);
    if (styleName != nil) {
        [self txtDidSelectStyle:styleName];
        return;
    }
    %orig;
}

%end

%hook UITextView

- (NSMethodSignature *)methodSignatureForSelector:(SEL)selector {
    NSMethodSignature *signature = %orig(selector);
    if (signature == nil && TXTLegacyStyleNameForSelector(selector) != nil) {
        signature = %orig(@selector(txtDidSelectStyle:));
    }
    return signature;
}

- (void)forwardInvocation:(NSInvocation *)invocation {
    NSString *styleName = TXTLegacyStyleNameForSelector(invocation.selector);
    if (styleName != nil) {
        [self txtDidSelectStyle:styleName];
        return;
    }
    %orig;
}

%end
%end

%group TXTLegacyCalloutTint

%hook UICalloutBar

- (void)layoutSubviews {
    %orig;
    UIView *background = TXTLegacyObjectIvar(self, "m_buttonView");
    background.backgroundColor = TXTLegacyMenuOpen ? kAccentColorAlpha : nil;
}

%end
%end

%group TXTLegacyCalloutIcon

%hook UICalloutBarButton

- (void)setupWithTitle:(id)title action:(SEL)action type:(int)type {
    if (action == @selector(txtOpenStyleMenu:)) {
        UIImage *image = TXTLegacyMenuImageProvider();
        if (image != nil) {
            [self setupWithImage:image action:action type:type];
            return;
        }
    }

    %orig;
}

%end
%end

#pragma mark - iOS 16+ Edit Menu

static NSString * const TXTStyleNamePropertyKey = @"TXTStyleName";
static NSString *TXTModernMenuTitle = @"Textyle";

/* UIImage file loading reaches UIScreen, which is not ready during dylib init. */
static UIImage *TXTModernMenuImageNone(void) {
    return nil;
}

static UIImage *TXTModernMenuImageTemplate(void) {
    static UIImage *image;
    if (image == nil) {
        image = [resizeImage([UIImage imageWithContentsOfFile:kMenuIcon],
                             CGSizeMake(18.0, 18.0))
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return image;
}

static UIImage *TXTModernMenuImageTinted(void) {
    static UIImage *image;
    if (image == nil) {
        image = [[resizeImage([UIImage imageWithContentsOfFile:kMenuIcon],
                              CGSizeMake(18.0, 18.0))
            imageWithTintColor:kAccentColor]
            imageWithRenderingMode:UIImageRenderingModeAlwaysOriginal];
    }
    return image;
}

static UIImage *(*TXTModernMenuImageProvider)(void) = TXTModernMenuImageNone;

static BOOL TXTMenuContainsStyles(UIMenu *menu) {
    if ([menu.identifier isEqualToString:kTextyleStylesMenuIdentifier]) {
        return YES;
    }

    for (UIMenuElement *element in menu.children) {
        if ([element isKindOfClass:[UIMenu class]] &&
            TXTMenuContainsStyles((UIMenu *)element)) {
            return YES;
        }
    }

    return NO;
}

static UIMenu *TXTMenuByAppendingStyles(UIMenu *originalMenu, UIResponder *target) {
    TXTStyleManager *manager = TXTStyleManager.sharedManager;

    if (manager.enabledStyles.count == 0) {
        return originalMenu;
    }

    UIResponder<UITextInput> *textInput = TXTResolveTextInput(target);
    if (!TXTReadSelectedText(textInput, NULL, NULL)) {
        return originalMenu;
    }

    if (TXTMenuContainsStyles(originalMenu)) {
        return originalMenu;
    }

    NSMutableArray<UIMenuElement *> *commands = [NSMutableArray array];
    for (NSDictionary *style in manager.enabledStyles) {
        NSString *name = style[@"name"];
        NSString *label = style[@"label"];
        UICommand *command = [UICommand commandWithTitle:label
                                                   image:nil
                                                  action:@selector(txtApplyStyleCommand:)
                                            propertyList:@{TXTStyleNamePropertyKey: name}];
        [commands addObject:command];
    }

    UIMenu *stylesMenu = [UIMenu menuWithTitle:TXTModernMenuTitle
                                         image:TXTModernMenuImageProvider()
                                    identifier:kTextyleStylesMenuIdentifier
                                       options:0
                                      children:commands];
    stylesMenu.accessibilityIdentifier = kTextyleStylesMenuIdentifier;

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject] appended styles menu process=%@ count=%lu target=%@ title=%@ image=%@",
          NSProcessInfo.processInfo.processName,
          (unsigned long)commands.count,
          NSStringFromClass(target.class),
          stylesMenu.title,
          stylesMenu.image == nil ? @"none" : NSStringFromCGSize(stylesMenu.image.size));
#endif

    if (originalMenu == nil) {
        return [UIMenu menuWithTitle:@"" children:@[stylesMenu]];
    }

    NSMutableArray<UIMenuElement *> *children = [originalMenu.children mutableCopy];
    [children addObject:stylesMenu];
    return [originalMenu menuByReplacingChildren:children];
}

%group TXTModernEditMenu

%hook UIEditMenuInteraction

- (void)_prepareMenuAtLocation:(CGPoint)location
                 configuration:(UIEditMenuConfiguration *)configuration
             completionHandler:(void (^)(UIMenu *preparedMenu))completionHandler {
    __weak UIEditMenuInteraction *weakInteraction = self;

    %orig(location, configuration, ^(UIMenu *preparedMenu) {
        UIResponder *target =
            [weakInteraction firstResponderTargetForConfiguration:configuration];
        completionHandler(TXTMenuByAppendingStyles(preparedMenu, target));
    });
}

%end
%end

%group TXTResponderActions

%hook UIResponder

- (BOOL)canPerformAction:(SEL)action withSender:(id)sender {
    if (action == @selector(txtApplyStyleCommand:)) {
        return TXTReadSelectedText(TXTResolveTextInput(self), NULL, NULL);
    }

    return %orig;
}

%new
- (void)txtApplyStyleCommand:(UICommand *)command {
    NSString *styleName = ((NSDictionary *)command.propertyList)[TXTStyleNamePropertyKey];

    UIResponder<UITextInput> *textInput = TXTResolveTextInput(self);
    UITextRange *selection = nil;
    NSString *selectedText = nil;
    if (!TXTReadSelectedText(textInput, &selection, &selectedText)) {
        return;
    }

    NSDictionary *style = [TXTStyleManager.sharedManager styleWithName:styleName];
    if (style == nil) {
        return;
    }

    NSString *replacement = [NSString stylizeText:selectedText withStyle:style];
    if (replacement != nil) {
        [textInput replaceRange:selection withText:replacement];
    }
}

%end
%end


static char TXTEditMenuTintOverlayKey;
static char TXTEditMenuPageButtonTintedKey;
static char TXTEditMenuPageButtonOriginalConfigurationKey;
static char TXTEditMenuPageButtonOriginalUpdateHandlerKey;
static char TXTEditMenuCellOriginalColorsKey;

static _UIEditMenuListView *TXTContainingEditMenuListView(UIView *view) {
    Class listViewClass = objc_getClass("_UIEditMenuListView");
    for (UIView *ancestor = view.superview;
         ancestor != nil;
         ancestor = ancestor.superview) {
        if ([ancestor isKindOfClass:listViewClass]) {
            return (_UIEditMenuListView *)ancestor;
        }
    }
    return nil;
}

static BOOL TXTShouldTintEditMenuListView(_UIEditMenuListView *listView) {
    UIMenu *menu = listView.displayedMenu;
    return
        [menu.identifier isEqualToString:kTextyleStylesMenuIdentifier] ||
        [menu.accessibilityIdentifier
            isEqualToString:kTextyleStylesMenuIdentifier];
}

static void TXTApplyEditMenuPageButtonTint(UIButton *button) {
    UIButtonConfiguration *configuration = button.configuration;
    configuration.baseForegroundColor = UIColor.whiteColor;
    configuration.background.backgroundColor = kAccentColor;
    configuration.background.visualEffect = nil;
    button.configuration = configuration;
    button.backgroundColor = kAccentColor;
    button.tintColor = UIColor.whiteColor;
}

static void TXTUpdateEditMenuPageButton(UIButton *button, BOOL shouldTint) {
    if (button == nil) {
        return;
    }

    BOOL isTinted = [objc_getAssociatedObject(button, &TXTEditMenuPageButtonTintedKey) boolValue];
    if (shouldTint) {
        if (!isTinted) {
            objc_setAssociatedObject(button, &TXTEditMenuPageButtonTintedKey, @YES, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(button, &TXTEditMenuPageButtonOriginalConfigurationKey, [button.configuration copy] ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
            objc_setAssociatedObject(button, &TXTEditMenuPageButtonOriginalUpdateHandlerKey, button.configurationUpdateHandler, OBJC_ASSOCIATION_COPY_NONATOMIC);
            button.configurationUpdateHandler = ^(UIButton *updatedButton) {
                id savedConfiguration = objc_getAssociatedObject(updatedButton, &TXTEditMenuPageButtonOriginalConfigurationKey);
                updatedButton.configuration = savedConfiguration == NSNull.null ? nil : [savedConfiguration copy];
                UIButtonConfigurationUpdateHandler originalHandler = objc_getAssociatedObject(updatedButton, &TXTEditMenuPageButtonOriginalUpdateHandlerKey);
                if (originalHandler != nil) {
                    originalHandler(updatedButton);
                }
                objc_setAssociatedObject(updatedButton, &TXTEditMenuPageButtonOriginalConfigurationKey, [updatedButton.configuration copy] ?: NSNull.null, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
                TXTApplyEditMenuPageButtonTint(updatedButton);
            };
        }
        TXTApplyEditMenuPageButtonTint(button);
        [button setNeedsUpdateConfiguration];
    } else if (isTinted) {
        id savedConfiguration = objc_getAssociatedObject(button, &TXTEditMenuPageButtonOriginalConfigurationKey);
        UIButtonConfigurationUpdateHandler originalHandler = objc_getAssociatedObject(button, &TXTEditMenuPageButtonOriginalUpdateHandlerKey);
        objc_setAssociatedObject(button, &TXTEditMenuPageButtonTintedKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        button.configurationUpdateHandler = originalHandler;
        button.configuration = savedConfiguration == NSNull.null ? nil : [savedConfiguration copy];
        objc_setAssociatedObject(button, &TXTEditMenuPageButtonOriginalConfigurationKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, &TXTEditMenuPageButtonOriginalUpdateHandlerKey, nil, OBJC_ASSOCIATION_COPY_NONATOMIC);
        [button setNeedsUpdateConfiguration];
        [button updateConfiguration];
        button.backgroundColor = UIColor.clearColor;
        button.tintColor = nil;
    }
}

static void TXTUpdateEditMenuTint(_UIEditMenuListView *listView) {
    UIView *backgroundView = listView.backgroundView;
    UIView *host = [backgroundView isKindOfClass:[UIVisualEffectView class]]
        ? ((UIVisualEffectView *)backgroundView).contentView
        : backgroundView;
    if (host == nil) {
        return;
    }

    UIView *overlay = objc_getAssociatedObject(listView, &TXTEditMenuTintOverlayKey);
    if (overlay.superview != host) {
        [overlay removeFromSuperview];
        overlay = [[UIView alloc] initWithFrame:host.bounds];
        overlay.userInteractionEnabled = NO;
        overlay.autoresizingMask = UIViewAutoresizingFlexibleWidth |
                                   UIViewAutoresizingFlexibleHeight;
        objc_setAssociatedObject(listView,
                                 &TXTEditMenuTintOverlayKey,
                                 overlay,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    [host insertSubview:overlay atIndex:0];
    overlay.frame = host.bounds;

    BOOL shouldTint = TXTShouldTintEditMenuListView(listView);
    overlay.hidden = !shouldTint;
    overlay.backgroundColor = shouldTint
        ? kAccentColor
        : UIColor.clearColor;
    TXTUpdateEditMenuPageButton(listView.leftButton, shouldTint);
    TXTUpdateEditMenuPageButton(listView.rightButton, shouldTint);
}

static void TXTUpdateEditMenuCellTint(_UIEditMenuListViewCell *cell, BOOL shouldTint) {
    NSArray *originalColors = objc_getAssociatedObject(cell, &TXTEditMenuCellOriginalColorsKey);
    if (shouldTint) {
        if (originalColors == nil) {
            originalColors = @[cell.titleLabel.textColor ?: NSNull.null, cell.imageView.tintColor ?: NSNull.null];
            objc_setAssociatedObject(cell, &TXTEditMenuCellOriginalColorsKey, originalColors, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
        cell.titleLabel.textColor = UIColor.whiteColor;
        cell.imageView.tintColor = UIColor.whiteColor;
    } else if (originalColors != nil) {
        cell.titleLabel.textColor = originalColors[0] == NSNull.null ? nil : originalColors[0];
        cell.imageView.tintColor = originalColors[1] == NSNull.null ? nil : originalColors[1];
        objc_setAssociatedObject(cell, &TXTEditMenuCellOriginalColorsKey, nil, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

%group TXTModernEditMenuTint

%hook _UIEditMenuListView

- (instancetype)initWithDelegate:(id)delegate menu:(UIMenu *)menu titleView:(UIView *)titleView preferredElementDisplayMode:(NSUInteger)preferredElementDisplayMode {
    self = %orig(delegate, menu, titleView, preferredElementDisplayMode);
    if (self != nil) {
        TXTUpdateEditMenuTint(self);
    }
    return self;
}

- (void)reloadWithMenu:(UIMenu *)menu
             titleView:(UIView *)titleView
              animated:(BOOL)animated {
    %orig(menu, titleView, animated);
    TXTUpdateEditMenuTint(self);
}

- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath {
    %orig(collectionView, cell, indexPath);
    if ([cell isKindOfClass:objc_getClass("_UIEditMenuListViewCell")]) {
        TXTUpdateEditMenuCellTint((_UIEditMenuListViewCell *)cell, TXTShouldTintEditMenuListView(self));
    }
}

%end

%hook _UIEditMenuListViewCell

- (void)prepareForReuse {
    TXTUpdateEditMenuCellTint(self, NO);
    %orig;
}

%end

%hook _UIEditMenuPageButton

- (void)setHighlighted:(BOOL)highlighted {
    %orig;
    _UIEditMenuListView *listView = TXTContainingEditMenuListView(self);
    TXTUpdateEditMenuPageButton(
        self, TXTShouldTintEditMenuListView(listView));
}

%end
%end

%ctor {
    @autoreleasepool {
        NSString *bundleIdentifier = NSBundle.mainBundle.bundleIdentifier;

        char **argv = *_NSGetArgv();
        if (argv == NULL || argv[0] == NULL) {
            return;
        }

        const char *executablePath = argv[0];
        BOOL isApplication = strstr(executablePath, "/Application") != NULL;
        BOOL isSpringBoard = strstr(executablePath, "/SpringBoard") != NULL;

        if (!isApplication && !isSpringBoard) {
            return;
        }

#if defined(TEXTYLE_SIMJECT)
        NSLog(@"[Textyle][Simject] loaded process=%@ bundle=%@",
              NSProcessInfo.processInfo.processName,
              bundleIdentifier);
#endif

        NSDictionary *loadedPreferences = [NSDictionary dictionaryWithContentsOfFile:kPrefsPath] ? : @{};
        NSArray *excludedApplications = loadedPreferences[@"enabledApps"];
        if ([excludedApplications containsObject:bundleIdentifier]) {
#if defined(TEXTYLE_SIMJECT)
            NSLog(@"[Textyle][Simject][Preferences] process=%@ excluded=YES",
                  NSProcessInfo.processInfo.processName);
#endif
            return;
        }

        if (!TXTPreferenceBool(loadedPreferences, @"Enabled", YES)) {
#if defined(TEXTYLE_SIMJECT)
            NSLog(@"[Textyle][Simject][Preferences] process=%@ enabled=NO",
                  NSProcessInfo.processInfo.processName);
#endif
            return;
        }

        BOOL keyboardToggleEnabled =
            TXTPreferenceBool(loadedPreferences, @"ToggleMenu", YES);
        BOOL tintMenu = TXTPreferenceBool(loadedPreferences, @"TintMenu", YES);
        BOOL menuIcon = TXTPreferenceBool(loadedPreferences, @"MenuIcon", YES);
        BOOL tintIcon = TXTPreferenceBool(loadedPreferences, @"TintIcon", NO);
        TXTLiveTypingActive = NO;
        TXTDockUsesTextyle =
            TXTPreferenceBool(loadedPreferences, @"DockUsesTextyle", YES);

        NSString *menuLabel = loadedPreferences[@"MenuLabel"] ?: @"Textyle";
        if (menuLabel.length == 0 ||
            [menuLabel caseInsensitiveCompare:@"Styles"] == NSOrderedSame) {
            menuLabel = @"Textyle";
        }

        id activeStyleValue = loadedPreferences[@"ActiveStyle"];
        TXTActiveStyleName =
            [activeStyleValue isKindOfClass:[NSString class]] &&
            [(NSString *)activeStyleValue length] > 0
                ? [activeStyleValue copy]
                : nil;
#if defined(TEXTYLE_SIMJECT)
        NSString *requestedStyleName = [TXTActiveStyleName copy];
#endif
        TXTLiveStateGeneration = 1;

        [TXTStyleManager sharedManager];

#if defined(TEXTYLE_SIMJECT)
        TXTStyleManager *manager = [TXTStyleManager sharedManager];
        NSString *menuImageMode = !menuIcon
            ? @"none"
            : (tintIcon ? @"tinted" : @"template");
        NSLog(@"[Textyle][Simject][Preferences] process=%@ enabled=YES toggle=%@ tint-menu=%@ menu-image=%@ menu-label=%@ requested-style=%@ effective-style=%@ dock-textyle=%@ live=%@",
              NSProcessInfo.processInfo.processName,
              keyboardToggleEnabled ? @"YES" : @"NO",
              tintMenu ? @"YES" : @"NO",
              menuImageMode,
              menuLabel,
              requestedStyleName ?: @"default",
              manager.activeStyle[@"name"] ?: @"none",
              TXTDockUsesTextyle ? @"YES" : @"NO",
              TXTLiveTypingActive ? @"YES" : @"NO");
#endif

        if (@available(iOS 16.0, *)) {
            TXTModernMenuTitle = [menuLabel copy];
            TXTModernMenuImageProvider = !menuIcon
                ? TXTModernMenuImageNone
                : (tintIcon
                    ? TXTModernMenuImageTinted
                    : TXTModernMenuImageTemplate);
            %init(TXTResponderActions);
            %init(TXTModernEditMenu);

#if defined(TEXTYLE_SIMJECT)
            NSLog(@"[Textyle][Simject] modern edit-menu hooks installed process=%@",
                  NSProcessInfo.processInfo.processName);
#endif

            if (tintMenu && objc_getClass("UIGlassEffect") == nil) {
                %init(TXTModernEditMenuTint);
#if defined(TEXTYLE_SIMJECT)
                NSLog(@"[Textyle][Simject] modern edit-menu tint hooks installed process=%@",
                      NSProcessInfo.processInfo.processName);
#endif
            }
        } else {
            TXTLegacyMenuTitle = [menuLabel copy];
            %init(TXTLegacyCalloutMenu);

            [[NSNotificationCenter defaultCenter]
                addObserverForName:UIMenuControllerDidHideMenuNotification
                            object:nil
                             queue:nil
                        usingBlock:^(NSNotification *notification) {
                TXTLegacyMenuOpen = NO;
            }];

            if (tintMenu) {
                %init(TXTLegacyCalloutTint);
            }
            if (menuIcon) {
                TXTLegacyMenuImageProvider = tintIcon
                    ? TXTLegacyMenuImageTinted
                    : TXTLegacyMenuImageTemplate;
                %init(TXTLegacyCalloutIcon);
            }
        }

        if (keyboardToggleEnabled) {
            static TXTDistributedStateObserver *stateObserver;
            stateObserver = [[TXTDistributedStateObserver alloc] init];
            NSDistributedNotificationCenter *distributedCenter =
                [NSDistributedNotificationCenter defaultCenter];
            [distributedCenter addObserver:stateObserver
                                  selector:@selector(dockModeDidChange:)
                                      name:TXTDockModeDidChangeDistributedNotification
                                    object:nil];

            /* The dock controller executes in the UIKit client. */
            if (@available(iOS 18.0, *)) {
                TXTInitializeModernDockHooks();
            } else {
                TXTInitializeLegacyDockHooks();
            }

            /* The final input delegate manager that commits text is client-side. */
            TXTInitializeKeyboardInputHooks();
        }

#if defined(TEXTYLE_SIMJECT)
        if ([bundleIdentifier isEqualToString:@"com.apple.MobileSMS"]) {
            if (@available(iOS 16.0, *)) {
                NSString *probeTitle = [TXTModernMenuTitle copy];
                UIImage *(*probeImageProvider)(void) = TXTModernMenuImageProvider;
                dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                             (int64_t)(0.5 * NSEC_PER_SEC)),
                               dispatch_get_main_queue(), ^{
                    UIImage *probeImage = probeImageProvider();
                    NSString *rendering = probeImage == nil
                        ? @"none"
                        : (probeImage.renderingMode == UIImageRenderingModeAlwaysTemplate
                            ? @"template"
                            : @"original");
                    NSLog(@"[Textyle][Simject][Preferences] runtime process=%@ menu-title=%@ image=%@ rendering=%@",
                          NSProcessInfo.processInfo.processName,
                          probeTitle,
                          probeImage == nil ? @"none" : NSStringFromCGSize(probeImage.size),
                          rendering);
                });
            }
        }

        TXTRunSimulatorSelfTestsIfNeeded();
#endif
    }
}
