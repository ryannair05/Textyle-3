#import <UIKit/UIKit.h>

#import "TXTStyleManager.h"

NS_ASSUME_NONNULL_BEGIN

@interface TXTStyleSelectionController : UIViewController <UICollectionViewDelegate> {
    NSArray<NSDictionary *> *styles;
    TXTStyleManager *styleManager;
}
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSNumber *, NSString *> *dataSource;
@property (nonatomic, copy, nullable) dispatch_block_t dockAppearanceDidChange;
@property (nonatomic, weak, nullable) UIView *sourceView;
@end

NS_ASSUME_NONNULL_END
