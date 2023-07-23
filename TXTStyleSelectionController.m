#import "TXTStyleSelectionController.h"
#import "TXTStyleCell.h"
#import "TXTConstants.h"

@interface NSDistributedNotificationCenter : NSNotificationCenter
@end

@implementation TXTStyleSelectionController

- (void)viewDidLoad {
    styleManager = [TXTStyleManager sharedManager];
    
    [super viewDidLoad];
    
    [[NSDistributedNotificationCenter defaultCenter] addObserver:self selector:@selector(selectActiveStyle:) name:@"TextyleStyleDidChange" object:nil];
    
    [self configureCollectionView];
    [self configureDataSource];
}

- (void)selectActiveStyle:(NSNotification *)notification {
    NSString *activeStyle = notification.userInfo[@"ActiveStyle"];

    NSUInteger index = [styles indexOfObjectPassingTest:^BOOL (NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        return [[dict objectForKey:@"name"] isEqualToString:activeStyle];
    }];
    
    NSAssert(index != NSNotFound, @"Textyle could not find an index for the active style. This should never happen");

    if([self presentingViewController]) {
        NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
        [self.collectionView selectItemAtIndexPath:selectedIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionNone];
    }
}

- (void)viewWillAppear:(BOOL)animated {
    NSString *activeStyle = [styleManager activeStyle][@"name"];

    NSUInteger index = [styles indexOfObjectPassingTest:^BOOL (NSDictionary *dict, NSUInteger idx, BOOL *stop) {
        return [[dict objectForKey:@"name"] isEqualToString:activeStyle];
    }];
    
    NSAssert(index != NSNotFound, @"Textyle could not find an index for the active style. This should never happen");
    
    NSIndexPath *selectedIndexPath = [NSIndexPath indexPathForRow:index inSection:0];
    [self.collectionView layoutIfNeeded];
    [self.collectionView selectItemAtIndexPath:selectedIndexPath animated:NO scrollPosition:UICollectionViewScrollPositionCenteredVertically];
}

- (void)configureCollectionView {
    self.collectionView = [[UICollectionView alloc] initWithFrame:CGRectNull collectionViewLayout:[self createBasicListLayout]];
    self.collectionView.delegate = self;

    _collectionView.backgroundColor = [UIColor clearColor];
    _collectionView.translatesAutoresizingMaskIntoConstraints = NO;
    _collectionView.layer.cornerRadius = kCornerRadius;
    _collectionView.layer.shadowColor = [UIColor blackColor].CGColor;
    _collectionView.layer.shadowOffset = CGSizeMake(0.0f, 5.0f);
    _collectionView.layer.shadowRadius = 10.0f;
    _collectionView.layer.shadowOpacity = 0.27f;
    
    [self.view addSubview:self.collectionView];
    
    [self.collectionView.centerXAnchor constraintEqualToAnchor:self.view.centerXAnchor].active = YES;
    [self.collectionView.centerYAnchor constraintEqualToAnchor:self.view.centerYAnchor].active = YES;
    [self.collectionView.heightAnchor constraintEqualToConstant:kMenuHeight].active = YES;
    [self.collectionView.widthAnchor constraintEqualToConstant:kMenuWidth].active = YES;

    UIVisualEffectView *blurEffectView = [[UIVisualEffectView alloc] initWithEffect:[UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemChromeMaterial]];
    blurEffectView.translatesAutoresizingMaskIntoConstraints = false;
    blurEffectView.layer.cornerRadius = kCornerRadius;
    blurEffectView.clipsToBounds = true;
    [self.view addSubview: blurEffectView];
    [self.view sendSubviewToBack: blurEffectView];

    [blurEffectView.topAnchor constraintEqualToAnchor:self.collectionView.topAnchor].active = YES;
    [blurEffectView.leadingAnchor constraintEqualToAnchor:self.collectionView.leadingAnchor].active = YES;
    [blurEffectView.trailingAnchor constraintEqualToAnchor:self.collectionView.trailingAnchor].active = YES;
    [blurEffectView.bottomAnchor constraintEqualToAnchor:self.collectionView.bottomAnchor].active = YES;
}

- (UICollectionViewLayout *)createBasicListLayout {
    NSCollectionLayoutSize *itemSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0] heightDimension:[NSCollectionLayoutDimension fractionalHeightDimension:1.0]];

    NSCollectionLayoutItem *item = [NSCollectionLayoutItem itemWithLayoutSize:itemSize];

    NSCollectionLayoutSize *groupSize = [NSCollectionLayoutSize sizeWithWidthDimension:[NSCollectionLayoutDimension fractionalWidthDimension:1.0] heightDimension:[NSCollectionLayoutDimension absoluteDimension:48.0]];

    NSCollectionLayoutGroup *group = [NSCollectionLayoutGroup horizontalGroupWithLayoutSize:groupSize subitems:@[item]];

    NSCollectionLayoutSection *section = [NSCollectionLayoutSection sectionWithGroup:group];

    UICollectionViewCompositionalLayout *layout = [[UICollectionViewCompositionalLayout alloc] initWithSection:section];

    return layout;
}

- (void)configureDataSource {
    styles = [styleManager enabledStyles];

    UICollectionViewCellRegistration *cellRegistration = [UICollectionViewCellRegistration registrationWithCellClass:[TXTStyleCell class] configurationHandler:^(TXTStyleCell *cell, NSIndexPath *indexPath, id item) {
        cell.label.text = item;
    }];
    
    self.dataSource = [[UICollectionViewDiffableDataSource alloc] initWithCollectionView:self.collectionView cellProvider:^TXTStyleCell *(UICollectionView *collectionView, NSIndexPath *indexPath, id item) {
        return [collectionView dequeueConfiguredReusableCellWithRegistration:cellRegistration forIndexPath:indexPath item:item];
    }];
    
    NSDiffableDataSourceSnapshot *snapshot = [[NSDiffableDataSourceSnapshot alloc] init];
    [snapshot appendSectionsWithIdentifiers:@[@0]];
    NSArray *labels = [styles valueForKey:@"label"];
    [snapshot appendItemsWithIdentifiers:labels];
    [self.dataSource applySnapshot:snapshot animatingDifferences:NO];
}

- (void)collectionView:(UICollectionView *)collectionView didSelectItemAtIndexPath:(NSIndexPath *)indexPath {
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)collectionView:(UICollectionView *)collectionView didHighlightItemAtIndexPath:(NSIndexPath *)indexPath {
    UISelectionFeedbackGenerator *hapticFeedbackGenerator = [[UISelectionFeedbackGenerator alloc] init];

    [hapticFeedbackGenerator selectionChanged];
    hapticFeedbackGenerator = nil;
}

- (void)touchesEnded:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    [self dismissViewControllerAnimated:YES completion:nil];
}
@end
