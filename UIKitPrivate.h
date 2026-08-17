#pragma once

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface UIEditMenuInteraction (TXTPrivate)

- (nullable UIResponder *)firstResponderTargetForConfiguration:
    (UIEditMenuConfiguration *)configuration API_AVAILABLE(ios(16.0));

- (void)_prepareMenuAtLocation:(CGPoint)location
                 configuration:(UIEditMenuConfiguration *)configuration
             completionHandler:(void (^)(UIMenu * _Nullable menu))completionHandler
    API_AVAILABLE(ios(16.0));

@end

API_AVAILABLE(ios(16.0))
@interface _UIEditMenuListView : UIView

@property (nonatomic, readonly, nullable) UIMenu *displayedMenu;
@property (nonatomic, readonly) UIView *backgroundView;
@property (nonatomic, readonly) UICollectionView *collectionView;
@property (nonatomic, readonly, nullable) UIButton *leftButton;
@property (nonatomic, readonly, nullable) UIButton *rightButton;

- (instancetype)initWithDelegate:(nullable id)delegate menu:(nullable UIMenu *)menu titleView:(nullable UIView *)titleView preferredElementDisplayMode:(NSUInteger)preferredElementDisplayMode;
- (void)reloadWithMenu:(nullable UIMenu *)menu
             titleView:(nullable UIView *)titleView
              animated:(BOOL)animated;
- (void)collectionView:(UICollectionView *)collectionView willDisplayCell:(UICollectionViewCell *)cell forItemAtIndexPath:(NSIndexPath *)indexPath;

@end

API_AVAILABLE(ios(16.0))
@interface _UIEditMenuListViewCell : UICollectionViewCell
@property (nonatomic, readonly) UILabel *titleLabel;
@property (nonatomic, readonly) UIImageView *imageView;
@end

API_AVAILABLE(ios(16.0))
@interface _UIEditMenuPageButton : UIButton
@end

@interface UIResponder (TXTTextInputPrivate)

@property (nonatomic, readonly, nullable) UIResponder<UITextInput> *_proxyTextInput API_AVAILABLE(ios(9.0));
- (void)txtApplyStyleCommand:(UICommand *)command;

@end

API_AVAILABLE(ios(11.0))
@interface UIKeyboardDockItemButton : UIButton
@end

API_AVAILABLE(ios(11.0))
@interface UIKeyboardDockItem : NSObject

@property (nonatomic, readonly) UIKeyboardDockItemButton *button;
@property (nonatomic, readonly, copy) NSString *identifier;
@property (nonatomic, getter=isEnabled) BOOL enabled;
@property (nonatomic, strong, nullable) UIAction *customAction API_AVAILABLE(ios(18.0));

- (void)setTitle:(NSString *)title image:(nullable UIImage *)image API_AVAILABLE(ios(18.0));

@end

API_AVAILABLE(ios(15.0))
@interface UIKeyboardDockView : UIView

@property (nonatomic, strong, nullable) UIKeyboardDockItem *rightDockItem;

@end

API_AVAILABLE(ios(11.0))
@interface UISystemKeyboardDockController : UIViewController

@property (nonatomic, strong) UIKeyboardDockView *dockView;

- (void)updateDockItemsVisibility;
- (void)keyboardDockView:(UIKeyboardDockView *)dockView
        didPressDockItem:(UIKeyboardDockItem *)dockItem
               withEvent:(nullable UIEvent *)event;
- (void)updateDockItemsVisibilityWithCustomDictationAction:(nullable UIAction *)action
    API_AVAILABLE(ios(18.0));

@end

API_AVAILABLE(ios(15.0))
@interface UIKBInputDelegateManager : NSObject

- (void)insertText:(NSString *)text updateInputSource:(BOOL)updateInputSource;

@end

NS_ASSUME_NONNULL_END
