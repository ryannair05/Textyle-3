#pragma once

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface NSDistributedNotificationCenter : NSNotificationCenter
+ (instancetype)defaultCenter;
@end

FOUNDATION_EXPORT NSNotificationName const TXTLiveStateDidChangeNotification;
FOUNDATION_EXPORT NSString * const TXTStyleDidChangeDistributedNotification;
FOUNDATION_EXPORT NSString * const TXTDockModeDidChangeDistributedNotification;

FOUNDATION_EXPORT BOOL TXTLiveTypingActive;
FOUNDATION_EXPORT BOOL TXTDockUsesTextyle;
FOUNDATION_EXPORT NSString * _Nullable TXTActiveStyleName;
FOUNDATION_EXPORT NSUInteger TXTLiveStateGeneration;

#ifdef __cplusplus
extern "C" {
#endif

UIImage * _Nullable resizeImage(UIImage * _Nullable image, CGSize size);
void TXTSetLiveTypingActive(BOOL active);
void TXTSetDockUsesTextyleAndBroadcast(BOOL usesTextyle);

void TXTInitializeLegacyDockHooks(void);
void TXTInitializeModernDockHooks(void);

#if defined(TEXTYLE_SIMJECT)
BOOL TXTModernDockTintIsActiveForTesting(void);
BOOL TXTModernDockImageIsTextyleForTesting(void);
#endif

void TXTInitializeKeyboardInputHooks(void);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
