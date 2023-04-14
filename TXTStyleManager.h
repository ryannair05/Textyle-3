#import <UIKit/UIKit.h>

@interface TXTStyleManager : NSObject
@property (nonatomic, strong) NSDictionary *activeStyle;
@property (nonatomic, strong) NSArray *enabledStyles;
+ (instancetype)sharedManager;
- (void)selectStyle:(NSString *)name;
- (NSDictionary *)styleWithName:(NSString *)name;
@end

FOUNDATION_EXPORT CFNotificationCenterRef CFNotificationCenterGetDistributedCenter(void);