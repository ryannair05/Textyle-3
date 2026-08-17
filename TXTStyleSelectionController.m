#import "TXTStyleSelectionController.h"
#import "TXTStyleCell.h"
#import "TXTConstants.h"
#import "Tweak.h"

#import <UIKit/UIGlassEffect.h>
#import <objc/message.h>
#import <objc/runtime.h>

static BOOL TXTDictationIsRunning(void) {
    /*
     * UIDictationController is registered at runtime on iOS 15, but UIKit does
     * not export its OBJC_CLASS symbol there. A direct class declaration/send
     * makes dyld reject Textyle before %ctor, so keep this lookup dynamic.
     */
    Class controllerClass = objc_getClass("UIDictationController");
    SEL selector = @selector(isRunning);
    return ((BOOL (*)(id, SEL))objc_msgSend)(controllerClass, selector);
}

@interface TXTStyleSelectionController ()
@property (nonatomic, strong) UIView *backdropView;
@property (nonatomic, strong) UIButton *dictationButton;
@property (nonatomic, strong) UIView *surfaceContainer;
@property (nonatomic, strong) UIVisualEffectView *backgroundEffectView;
@property (nonatomic, strong) UIView *utilitySeparator;
@property (nonatomic) BOOL hasAnimatedPresentation;
@property (nonatomic) BOOL isDismissingStyleSelector;
- (void)selectActiveStyleWithScrollPosition:(UICollectionViewScrollPosition)scrollPosition;
- (void)updateDockModeButton;
- (void)toggleDockMode;
- (void)dismissStyleSelector;
@end

@implementation TXTStyleSelectionController

- (void)viewDidLoad {
    [super viewDidLoad];
    styleManager = [TXTStyleManager sharedManager];

    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(activeStyleDidChange:)
                                                 name:TXTActiveStyleDidChangeNotification
                                               object:styleManager];

    [self configureCollectionView];
    [self configureDataSource];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)activeStyleDidChange:(NSNotification *)notification {
    [self selectActiveStyleWithScrollPosition:UICollectionViewScrollPositionNone];
}

- (void)selectActiveStyleWithScrollPosition:(UICollectionViewScrollPosition)scrollPosition {
    NSString *activeStyle = styleManager.activeStyle[@"name"];
    NSUInteger index = [styles indexOfObjectPassingTest:^BOOL (NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        return [[dict objectForKey:@"name"] isEqualToString:activeStyle];
    }];

    if (index == NSNotFound) {
        return;
    }

    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForItem:index inSection:0];
    [self.collectionView selectItemAtIndexPath:selectedIndexPath
                                      animated:NO
                                scrollPosition:scrollPosition];
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [self.view layoutIfNeeded];
    [self selectActiveStyleWithScrollPosition:
        UICollectionViewScrollPositionCenteredVertically];
    [self updateDockModeButton];

    if (!self.hasAnimatedPresentation) {
        CGPoint sourcePoint = CGPointMake(CGRectGetMidX(self.surfaceContainer.bounds),
                                          CGRectGetMaxY(self.surfaceContainer.bounds));
        if (self.sourceView != nil) {
            CGRect sourceRect = [self.sourceView convertRect:self.sourceView.bounds
                                                      toView:self.surfaceContainer];
            sourcePoint.x = MIN(CGRectGetMaxX(self.surfaceContainer.bounds),
                                MAX(CGRectGetMinX(self.surfaceContainer.bounds),
                                    CGRectGetMidX(sourceRect)));
            sourcePoint.y = MIN(CGRectGetMaxY(self.surfaceContainer.bounds),
                                MAX(CGRectGetMinY(self.surfaceContainer.bounds),
                                    CGRectGetMidY(sourceRect)));
        }

        self.backdropView.alpha = 0.0;
        self.surfaceContainer.alpha = 0.0;
        if (!UIAccessibilityIsReduceMotionEnabled()) {
            CGFloat scale = 0.88;
            CGPoint surfaceCenter = CGPointMake(
                CGRectGetMidX(self.surfaceContainer.bounds),
                CGRectGetMidY(self.surfaceContainer.bounds));
            self.surfaceContainer.transform = CGAffineTransformMake(
                scale,
                0.0,
                0.0,
                scale,
                (1.0 - scale) * (sourcePoint.x - surfaceCenter.x),
                (1.0 - scale) * (sourcePoint.y - surfaceCenter.y) + 8.0);
        }
    }
}

- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
    if (self.hasAnimatedPresentation) {
        return;
    }
    self.hasAnimatedPresentation = YES;

    [UIView animateWithDuration:0.18
                          delay:0.0
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.backdropView.alpha = 1.0;
    } completion:nil];

    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.16 : 0.30;
    [UIView animateWithDuration:duration
                          delay:0.0
         usingSpringWithDamping:0.84
          initialSpringVelocity:0.10
                        options:UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.surfaceContainer.alpha = 1.0;
        self.surfaceContainer.transform = CGAffineTransformIdentity;
    } completion:^(BOOL finished) {
#if defined(TEXTYLE_SIMJECT)
        NSLog(@"[Textyle][Simject] style selector animation %@ source=%@ center={%.1f, %.1f}",
              finished ? @"PASS" : @"INTERRUPTED",
              self.sourceView == nil ? @"fallback" : NSStringFromClass(self.sourceView.class),
              self.surfaceContainer.center.x,
              self.surfaceContainer.center.y);
#endif
    }];
}

- (void)viewDidLayoutSubviews {
    [super viewDidLayoutSubviews];
    self.surfaceContainer.layer.shadowPath =
        [UIBezierPath bezierPathWithRoundedRect:self.surfaceContainer.bounds
                                   cornerRadius:kCornerRadius].CGPath;
}

- (void)configureCollectionView {
    self.view.backgroundColor = UIColor.clearColor;
    self.view.accessibilityViewIsModal = YES;

    self.backdropView = [[UIView alloc] initWithFrame:CGRectZero];
    self.backdropView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backdropView.backgroundColor =
        [UIColor colorWithWhite:0.0 alpha:0.08];
    self.backdropView.userInteractionEnabled = NO;
    self.backdropView.accessibilityIdentifier =
        @"com.ryannair05.textyle.style-selector.backdrop";
    [self.view addSubview:self.backdropView];

    self.surfaceContainer = [[UIView alloc] initWithFrame:CGRectZero];
    self.surfaceContainer.translatesAutoresizingMaskIntoConstraints = NO;
    self.surfaceContainer.backgroundColor = UIColor.clearColor;
    self.surfaceContainer.layer.cornerRadius = kCornerRadius;
    self.surfaceContainer.layer.cornerCurve = kCACornerCurveContinuous;
    self.surfaceContainer.layer.shadowColor = UIColor.blackColor.CGColor;
    if (@available(iOS 26.0, *)) {
        self.surfaceContainer.layer.shadowOffset = CGSizeZero;
        self.surfaceContainer.layer.shadowRadius = 0.0;
        self.surfaceContainer.layer.shadowOpacity = 0.0;
    } else {
        self.surfaceContainer.layer.shadowOffset = CGSizeMake(0.0, 8.0);
        self.surfaceContainer.layer.shadowRadius = 18.0;
        self.surfaceContainer.layer.shadowOpacity = 0.20;
    }
    self.surfaceContainer.accessibilityIdentifier =
        @"com.ryannair05.textyle.style-selector.surface";
    [self.view addSubview:self.surfaceContainer];

    UIVisualEffect *surfaceEffect;
    if (@available(iOS 26.0, *)) {
        surfaceEffect = [UIGlassEffect effectWithStyle:UIGlassEffectStyleRegular];
        [(UIGlassEffect * )surfaceEffect setInteractive:YES];
    } else {
        surfaceEffect =[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemMaterial];
    }

    self.backgroundEffectView = [[UIVisualEffectView alloc]
        initWithEffect:surfaceEffect];
    self.backgroundEffectView.translatesAutoresizingMaskIntoConstraints = NO;
    self.backgroundEffectView.layer.cornerRadius = kCornerRadius;
    self.backgroundEffectView.layer.cornerCurve = kCACornerCurveContinuous;
    self.backgroundEffectView.clipsToBounds = YES;
    self.backgroundEffectView.accessibilityIdentifier =
        @"com.ryannair05.textyle.style-selector.effect";
    [self.surfaceContainer addSubview:self.backgroundEffectView];

    UIView *contentView = self.backgroundEffectView.contentView;

    NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize
        sizeWithWidthDimension:[NSCollectionLayoutDimension
            fractionalWidthDimension:1.0]
                heightDimension:[NSCollectionLayoutDimension
            fractionalHeightDimension:1.0]];
    NSCollectionLayoutItem *item =
        [NSCollectionLayoutItem itemWithLayoutSize:itemSize];
    NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize
        sizeWithWidthDimension:[NSCollectionLayoutDimension
            fractionalWidthDimension:1.0]
                heightDimension:[NSCollectionLayoutDimension
            absoluteDimension:48.0]];
    NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup
        horizontalGroupWithLayoutSize:groupSize
                              subitems:@[item]];
    NSCollectionLayoutSection *section =
        [NSCollectionLayoutSection sectionWithGroup:group];
    UICollectionViewCompositionalLayout *layout =
        [[UICollectionViewCompositionalLayout alloc] initWithSection:section];

    self.collectionView = [[UICollectionView alloc]
        initWithFrame:CGRectZero
 collectionViewLayout:layout];
    self.collectionView.delegate = self;

    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.alwaysBounceVertical = YES;
    _collectionView.accessibilityIdentifier =
        @"com.ryannair05.textyle.style-selector.styles";
    [contentView addSubview:self.collectionView];

    self.dictationButton = [UIButton buttonWithType:UIButtonTypeSystem];
    self.dictationButton.translatesAutoresizingMaskIntoConstraints = NO;
    self.dictationButton.titleLabel.font = [UIFont preferredFontForTextStyle:UIFontTextStyleCallout];
    self.dictationButton.titleLabel.adjustsFontForContentSizeCategory = YES;
    [self.dictationButton setTitleColor:[UIColor.labelColor colorWithAlphaComponent:0.72]
                              forState:UIControlStateNormal];
    self.dictationButton.accessibilityIdentifier =
        @"com.ryannair05.textyle.style-selector.dictation";
    [self.dictationButton addTarget:self
                             action:@selector(toggleDockMode)
                   forControlEvents:UIControlEventTouchUpInside];
    [contentView addSubview:self.dictationButton];

    self.utilitySeparator = [[UIView alloc] initWithFrame:CGRectZero];
    self.utilitySeparator.translatesAutoresizingMaskIntoConstraints = NO;
    self.utilitySeparator.backgroundColor = UIColor.separatorColor;
    self.utilitySeparator.accessibilityIdentifier =
        @"com.ryannair05.textyle.style-selector.separator";
    [contentView addSubview:self.utilitySeparator];

    CGFloat separatorHeight = 1.0 / UIScreen.mainScreen.scale;
    CGFloat utilityRowHeight = 48.0;
    [NSLayoutConstraint activateConstraints:@[
        [self.backdropView.topAnchor constraintEqualToAnchor:self.view.topAnchor],
        [self.backdropView.leadingAnchor constraintEqualToAnchor:self.view.leadingAnchor],
        [self.backdropView.trailingAnchor constraintEqualToAnchor:self.view.trailingAnchor],
        [self.backdropView.bottomAnchor constraintEqualToAnchor:self.view.bottomAnchor],

        [self.surfaceContainer.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor],
        [self.surfaceContainer.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor
                                                            constant:-24.0],
        [self.surfaceContainer.widthAnchor constraintEqualToConstant:kMenuWidth],
        [self.surfaceContainer.heightAnchor
            constraintEqualToConstant:kMenuHeight + separatorHeight + utilityRowHeight],

        [self.backgroundEffectView.topAnchor constraintEqualToAnchor:self.surfaceContainer.topAnchor],
        [self.backgroundEffectView.leadingAnchor constraintEqualToAnchor:self.surfaceContainer.leadingAnchor],
        [self.backgroundEffectView.trailingAnchor constraintEqualToAnchor:self.surfaceContainer.trailingAnchor],
        [self.backgroundEffectView.bottomAnchor constraintEqualToAnchor:self.surfaceContainer.bottomAnchor],

        [self.collectionView.topAnchor constraintEqualToAnchor:contentView.topAnchor],
        [self.collectionView.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.collectionView.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.collectionView.heightAnchor constraintEqualToConstant:kMenuHeight],

        [self.utilitySeparator.topAnchor constraintEqualToAnchor:self.collectionView.bottomAnchor],
        [self.utilitySeparator.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor
                                                            constant:16.0],
        [self.utilitySeparator.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor
                                                             constant:-16.0],
        [self.utilitySeparator.heightAnchor constraintEqualToConstant:separatorHeight],

        [self.dictationButton.topAnchor constraintEqualToAnchor:self.utilitySeparator.bottomAnchor],
        [self.dictationButton.leadingAnchor constraintEqualToAnchor:contentView.leadingAnchor],
        [self.dictationButton.trailingAnchor constraintEqualToAnchor:contentView.trailingAnchor],
        [self.dictationButton.bottomAnchor constraintEqualToAnchor:contentView.bottomAnchor],
        [self.dictationButton.heightAnchor constraintEqualToConstant:utilityRowHeight],
    ]];
}

- (void)updateDockModeButton {
    BOOL dictationIsRunning = TXTDictationIsRunning();
    NSString *title = TXTDockUsesTextyle
        ? @"Use Dictation"
        : @"Use Textyle";
    [self.dictationButton setTitle:title forState:UIControlStateNormal];
    self.dictationButton.enabled = !dictationIsRunning;
    [self.dictationButton
        setTitleColor:[UIColor.labelColor
            colorWithAlphaComponent:dictationIsRunning ? 0.38 : 0.72]
             forState:UIControlStateNormal];
}

- (void)toggleDockMode {
    if (TXTDictationIsRunning()) {
        [self updateDockModeButton];
        return;
    }

    BOOL useTextyle = !TXTDockUsesTextyle;
    if (!useTextyle) {
        TXTSetLiveTypingActive(NO);
    }
    TXTSetDockUsesTextyleAndBroadcast(useTextyle);

    if (self.dockAppearanceDidChange != nil) {
        self.dockAppearanceDidChange();
    }
    [self dismissStyleSelector];
}

- (void)dismissStyleSelector {
    if (self.isDismissingStyleSelector) {
        return;
    }
    self.isDismissingStyleSelector = YES;

    NSTimeInterval duration = UIAccessibilityIsReduceMotionEnabled() ? 0.12 : 0.18;
    [UIView animateWithDuration:duration
                          delay:0.0
                        options:UIViewAnimationOptionCurveEaseIn |
                                UIViewAnimationOptionAllowUserInteraction |
                                UIViewAnimationOptionBeginFromCurrentState
                     animations:^{
        self.backdropView.alpha = 0.0;
        self.surfaceContainer.alpha = 0.0;
        if (!UIAccessibilityIsReduceMotionEnabled()) {
            self.surfaceContainer.transform = CGAffineTransformConcat(
                CGAffineTransformMakeTranslation(0.0, 5.0),
                CGAffineTransformMakeScale(0.94, 0.94));
        }
    } completion:^(BOOL finished) {
        [self dismissViewControllerAnimated:NO completion:nil];
    }];
}

- (void)configureDataSource {
    styles = [styleManager enabledStyles];

    UICollectionViewCellRegistration *cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:[TXTStyleCell class] configurationHandler:^(TXTStyleCell *cell, NSIndexPath *indexPath, id item) {
        NSDictionary *style = [styleManager styleWithName:item];
        cell.label.text = style[@"label"];
        cell.accessibilityLabel = cell.label.text;
    }];
    
    self.dataSource = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView cellProvider:^TXTStyleCell *(UICollectionView *collectionView, NSIndexPath *indexPath, id item) {
        return [collectionView dequeueConfiguredReusableCellWithRegistration:cellRegistration forIndexPath:indexPath item:item];
    }];
    
    NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    [snapshot appendSectionsWithIdentifiers:@[@0]];
    NSArray *styleNames = [styles valueForKey:@"name"];
    [snapshot appendItemsWithIdentifiers:styleNames];
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    NSString *name = styles[indexPath.item][@"name"];
    [styleManager selectStyle:name];
    TXTSetLiveTypingActive(YES);
    [self dismissStyleSelector];
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    UISelectionFeedbackGenerator *hapticFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];

    [hapticFeedbackGenerator selectionChanged];
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event {
    [self dismissStyleSelector];
}
@end
