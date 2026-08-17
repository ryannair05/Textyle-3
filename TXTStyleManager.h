#pragma once

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

FOUNDATION_EXPORT NSNotificationName const TXTActiveStyleDidChangeNotification;

@interface TXTStyleManager : NSObject

@property (nonatomic, strong, readonly, nullable) NSDictionary *activeStyle;
@property (nonatomic, copy, readonly) NSArray<NSDictionary *> *enabledStyles;

+ (instancetype)sharedManager;
- (void)selectStyle:(NSString *)name;
- (nullable NSDictionary *)styleWithName:(NSString *)name;

@end

NS_ASSUME_NONNULL_END
