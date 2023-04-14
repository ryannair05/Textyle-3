#import "TXTStyleManager.h"

@interface TXTStyleSelectionController : UIViewController <UICollectionViewDelegate> {
    NSArray *styles;
    TXTStyleManager *styleManager;
}
@property (nonatomic, strong) UICollectionView *collectionView;
@property (nonatomic, strong) UICollectionViewDiffableDataSource<NSString *, NSString *> *dataSource;
@end