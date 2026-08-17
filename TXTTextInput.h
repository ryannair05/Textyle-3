#pragma once

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

#ifdef __cplusplus
extern "C" {
#endif

UIResponder<UITextInput> * _Nullable TXTResolveTextInput(
    UIResponder * _Nullable startResponder);

BOOL TXTReadSelectedText(UIResponder<UITextInput> * _Nullable textInput,
                         UITextRange * _Nullable * _Nullable rangeOut,
                         NSString * _Nullable * _Nullable textOut);

#ifdef __cplusplus
}
#endif

NS_ASSUME_NONNULL_END
