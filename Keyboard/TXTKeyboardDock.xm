#import "../Tweak.h"

#import "../UIKitPrivate.h"
#import "../TXTConstants.h"
#import "../TXTStyleSelectionController.h"

#import <objc/runtime.h>

static char TXTDockStateObserverKey;
static char TXTLegacyDockConfiguredKey;
static char TXTLegacyDockSingleTapKey;
static char TXTLegacyDockLongPressKey;
static char TXTModernDockLongPressKey;
static char TXTModernDockRenderedImageKey;

#if defined(TEXTYLE_SIMJECT)
static __weak UISystemKeyboardDockController *TXTLastModernDockController;
#endif

static BOOL TXTIsLegacyDictationItem(UIKeyboardDockItem *item) {
    NSString *identifier = item.identifier;
    return [identifier isEqualToString:@"dictation"] ||
           [identifier isEqualToString:@"dictationRunning"];
}

static UIImage *TXTLegacyKeyboardDockImage(void) {
    static UIImage *image;
    if (image == nil) {
        image = [[UIImage imageWithContentsOfFile:kMenuIcon]
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate];
    }
    return image;
}

static UIImage *TXTModernKeyboardDockImage(void) {
    static UIImage *image;
    if (image == nil) {
        image = [[resizeImage([UIImage imageWithContentsOfFile:kMenuIcon],
                              CGSizeMake(25.0, 25.0))
            imageWithRenderingMode:UIImageRenderingModeAlwaysTemplate]
            imageWithAlignmentRectInsets:UIEdgeInsetsMake(0.0, 0.0, 2.0, 0.0)];
    }
    return image;
}

static void TXTInstallDockStateObserver(UISystemKeyboardDockController *controller) {
    if (objc_getAssociatedObject(controller, &TXTDockStateObserverKey) != nil) {
        return;
    }

    __weak UISystemKeyboardDockController *weakController = controller;
    id token = [[NSNotificationCenter defaultCenter]
        addObserverForName:TXTLiveStateDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *notification) {
        [weakController updateDockItemsVisibility];
    }];

    objc_setAssociatedObject(controller,
                             &TXTDockStateObserverKey,
                             token,
                             OBJC_ASSOCIATION_RETAIN_NONATOMIC);
}

static void TXTRemoveDockStateObserver(UISystemKeyboardDockController *controller) {
    id token = objc_getAssociatedObject(controller, &TXTDockStateObserverKey);
    if (token != nil) {
        [[NSNotificationCenter defaultCenter] removeObserver:token];
        objc_setAssociatedObject(controller,
                                 &TXTDockStateObserverKey,
                                 nil,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }
}

static void TXTPresentStyleChooser(UISystemKeyboardDockController *controller) {
    if (controller.presentedViewController != nil) {
        return;
    }

    TXTStyleSelectionController *chooser = [[TXTStyleSelectionController alloc] init];
    chooser.modalPresentationStyle = UIModalPresentationOverFullScreen;
    chooser.sourceView = controller.dockView.rightDockItem.button;

    __weak UISystemKeyboardDockController *weakController = controller;
    chooser.dockAppearanceDidChange = ^{
        [weakController updateDockItemsVisibility];
    };

    [controller presentViewController:chooser animated:NO completion:nil];

    UIImpactFeedbackGenerator *feedback =
        [[UIImpactFeedbackGenerator alloc] initWithStyle:UIImpactFeedbackStyleLight];
    [feedback prepare];
    [feedback impactOccurred];
}

static void TXTConfigureLegacyDock(UISystemKeyboardDockController *controller) {
    UIKeyboardDockItem *item = controller.dockView.rightDockItem;
    if (!TXTIsLegacyDictationItem(item)) {
        return;
    }

    UIKeyboardDockItemButton *button = item.button;
    if (button == nil) {
        return;
    }

    if (![objc_getAssociatedObject(button, &TXTLegacyDockConfiguredKey) boolValue]) {
        UITapGestureRecognizer *singleTap = [[UITapGestureRecognizer alloc]
            initWithTarget:controller
                    action:@selector(txtToggleActive:)];
        singleTap.numberOfTapsRequired = 1;
        singleTap.cancelsTouchesInView = NO;

        UILongPressGestureRecognizer *longPress = [[UILongPressGestureRecognizer alloc]
            initWithTarget:controller
                    action:@selector(txtShowStyleChooser:)];
        longPress.minimumPressDuration = 0.3;
        longPress.cancelsTouchesInView = YES;

        [button addGestureRecognizer:singleTap];
        [button addGestureRecognizer:longPress];

        objc_setAssociatedObject(button, &TXTLegacyDockConfiguredKey, @YES,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, &TXTLegacyDockSingleTapKey, singleTap,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        objc_setAssociatedObject(button, &TXTLegacyDockLongPressKey, longPress,
                                 OBJC_ASSOCIATION_RETAIN_NONATOMIC);
    }

    BOOL ownsDockSlot = TXTDockUsesTextyle;

    ((UITapGestureRecognizer *)objc_getAssociatedObject(
        button, &TXTLegacyDockSingleTapKey)).enabled = ownsDockSlot;
    ((UILongPressGestureRecognizer *)objc_getAssociatedObject(
        button, &TXTLegacyDockLongPressKey)).enabled = YES;

    if (ownsDockSlot) {
        item.enabled = YES;
        UIImage *image = TXTLegacyKeyboardDockImage();
        if (image != nil) {
            [button setImage:image forState:UIControlStateNormal];
        }
        button.tintColor = TXTLiveTypingActive ? kAccentColor : UIColor.labelColor;
    }
}

%group TXTDock15To17

%hook UIKeyboardDockItemButton

- (void)setTintColor:(UIColor *)color {
    if ([objc_getAssociatedObject(self, &TXTLegacyDockConfiguredKey) boolValue] &&
        TXTDockUsesTextyle) {
        color = TXTLiveTypingActive ? kAccentColor : UIColor.labelColor;
    }
    %orig(color);
}

- (void)setImage:(UIImage *)image forState:(UIControlState)state {
    if ([objc_getAssociatedObject(self, &TXTLegacyDockConfiguredKey) boolValue] &&
        TXTDockUsesTextyle) {
        UIImage *textyleImage = TXTLegacyKeyboardDockImage();
        if (textyleImage != nil) {
            image = textyleImage;
        }
    }
    %orig(image, state);
}

%end

%hook UISystemKeyboardDockController

- (void)loadView {
    %orig;
    TXTInstallDockStateObserver(self);
    TXTConfigureLegacyDock(self);
}

- (void)updateDockItemsVisibility {
    %orig;
    TXTConfigureLegacyDock(self);
}

- (void)keyboardDockView:(UIKeyboardDockView *)dockView
        didPressDockItem:(UIKeyboardDockItem *)dockItem
               withEvent:(UIEvent *)event {
    if (TXTDockUsesTextyle &&
        TXTIsLegacyDictationItem(dockItem)) {
        return;
    }

    %orig;
}

- (void)dealloc {
    TXTRemoveDockStateObserver(self);
    %orig;
}

%new
- (void)txtToggleActive:(UITapGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateEnded) {
        return;
    }

    TXTSetLiveTypingActive(!TXTLiveTypingActive);
}

%new
- (void)txtShowStyleChooser:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state == UIGestureRecognizerStateBegan) {
        TXTPresentStyleChooser(self);
    }
}

%end
%end

%group TXTDock18Plus

%hook UISystemKeyboardDockController

- (void)loadView {
    %orig;
    TXTInstallDockStateObserver(self);
    [self updateDockItemsVisibilityWithCustomDictationAction:nil];
}

- (void)updateDockItemsVisibility {
    %orig;
    [self updateDockItemsVisibilityWithCustomDictationAction:nil];
}

- (void)updateDockItemsVisibilityWithCustomDictationAction:(UIAction *)action {
    BOOL ownsDockSlot = TXTDockUsesTextyle;
    UIAction *effectiveAction = action;

    if (ownsDockSlot) {
        __weak UISystemKeyboardDockController *weakController = self;
        effectiveAction = [UIAction
            actionWithTitle:@"Textyle"
                      image:TXTModernKeyboardDockImage()
                 identifier:@"com.ryannair05.textyle.keyboard-dock"
                    handler:^(__kindof UIAction *selectedAction) {
            TXTSetLiveTypingActive(!TXTLiveTypingActive);
            [weakController updateDockItemsVisibility];

#if defined(TEXTYLE_SIMJECT)
            NSLog(@"[Textyle][Simject] dock action process=%@ active=%@",
                  NSProcessInfo.processInfo.processName,
                  TXTLiveTypingActive ? @"YES" : @"NO");
#endif
        }];
        effectiveAction.state = TXTLiveTypingActive
            ? UIMenuElementStateOn
            : UIMenuElementStateOff;
    }

    %orig(effectiveAction);

    UIKeyboardDockItem *rightItem = self.dockView.rightDockItem;
    if (ownsDockSlot) {
        UIImage *textyleImage = TXTModernKeyboardDockImage();
        if (textyleImage != nil) {
            [rightItem setTitle:@"Textyle" image:textyleImage];
        }
    } else if ([rightItem.customAction.identifier
                   isEqualToString:@"com.ryannair05.textyle.keyboard-dock"]) {
        rightItem.customAction = nil;
    }

    UIKeyboardDockItemButton *button = rightItem.button;
    if (button != nil) {
        UILongPressGestureRecognizer *longPress =
            objc_getAssociatedObject(button, &TXTModernDockLongPressKey);
        if (longPress == nil) {
            longPress = [[UILongPressGestureRecognizer alloc]
                initWithTarget:self
                        action:@selector(txtShowStyleChooser:)];
            longPress.minimumPressDuration = 0.3;
            longPress.cancelsTouchesInView = YES;
            [button addGestureRecognizer:longPress];
            objc_setAssociatedObject(button,
                                     &TXTModernDockLongPressKey,
                                     longPress,
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }

        longPress.enabled = YES;
        button.tintColor = ownsDockSlot
            ? (TXTLiveTypingActive ? kAccentColor : UIColor.labelColor)
            : nil;
        if (ownsDockSlot) {
            objc_setAssociatedObject(button,
                                     &TXTModernDockRenderedImageKey,
                                     [button imageForState:UIControlStateNormal],
                                     OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }

#if defined(TEXTYLE_SIMJECT)
    TXTLastModernDockController = self;
#endif

#if defined(TEXTYLE_SIMJECT)
    UIKeyboardDockItem *item = self.dockView.rightDockItem;
    NSLog(@"[Textyle][Simject] dock configured process=%@ owns=%@ active=%@ item=%@ action=%@ image=%@",
          NSProcessInfo.processInfo.processName,
          ownsDockSlot ? @"YES" : @"NO",
          TXTLiveTypingActive ? @"YES" : @"NO",
          item.identifier,
          item.customAction.identifier,
          effectiveAction.image == nil ? @"NO" : @"YES");
#endif
}

- (void)dealloc {
    TXTRemoveDockStateObserver(self);
    %orig;
}

%new
- (void)txtShowStyleChooser:(UILongPressGestureRecognizer *)gesture {
    if (gesture.state != UIGestureRecognizerStateBegan) {
        return;
    }

    TXTPresentStyleChooser(self);
}

%end

%hook UIKeyboardDockItem

- (UIKeyboardDockItemButton *)button {
    UIKeyboardDockItemButton *button = %orig;
    if ([self.customAction.identifier
            isEqualToString:@"com.ryannair05.textyle.keyboard-dock"]) {
        button.tintColor = TXTLiveTypingActive ? kAccentColor : UIColor.labelColor;
    }
    return button;
}

%end

%end

#if defined(TEXTYLE_SIMJECT)
BOOL TXTModernDockTintIsActiveForTesting(void) {
    UIKeyboardDockItemButton *button =
        TXTLastModernDockController.dockView.rightDockItem.button;
    UIColor *actual = [button.tintColor
        resolvedColorWithTraitCollection:button.traitCollection];
    UIColor *expected = [kAccentColor
        resolvedColorWithTraitCollection:button.traitCollection];
    return actual != nil && expected != nil &&
        CGColorEqualToColor(actual.CGColor, expected.CGColor);
}

BOOL TXTModernDockImageIsTextyleForTesting(void) {
    UIKeyboardDockItemButton *button =
        TXTLastModernDockController.dockView.rightDockItem.button;
    UIImage *expected = objc_getAssociatedObject(button,
                                                  &TXTModernDockRenderedImageKey);
    UIImage *rendered = [button imageForState:UIControlStateNormal];
    return expected != nil && rendered == expected &&
        rendered.alignmentRectInsets.bottom > 1.5;
}
#endif

void TXTInitializeLegacyDockHooks(void) {
    %init(TXTDock15To17);

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject] legacy dock hooks installed process=%@",
          NSProcessInfo.processInfo.processName);
#endif
}

void TXTInitializeModernDockHooks(void) {
    %init(TXTDock18Plus);

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject] modern dock hooks installed process=%@",
          NSProcessInfo.processInfo.processName);
#endif
}
