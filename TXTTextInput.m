#import "TXTTextInput.h"

#import "UIKitPrivate.h"

UIResponder<UITextInput> *TXTResolveTextInput(UIResponder *startResponder) {
    for (UIResponder *candidate = startResponder;
         candidate != nil;
         candidate = candidate.nextResponder) {
        if ([candidate conformsToProtocol:@protocol(UITextInput)]) {
            return (UIResponder<UITextInput> *)candidate;
        }

        if ([candidate respondsToSelector:@selector(_proxyTextInput)]) {
            UIResponder<UITextInput> *proxy = candidate._proxyTextInput;
            if (proxy != candidate &&
                [proxy conformsToProtocol:@protocol(UITextInput)]) {
                return proxy;
            }
        }
    }

    return nil;
}

BOOL TXTReadSelectedText(UIResponder<UITextInput> *textInput,
                         UITextRange **rangeOut,
                         NSString **textOut) {
    UITextRange *range = textInput.selectedTextRange;
    if (range == nil) {
        return NO;
    }

    NSInteger selectedLength = [textInput offsetFromPosition:range.start toPosition:range.end];
    if (selectedLength <= 0) {
        return NO;
    }

    NSString *text = [textInput textInRange:range];
    if (!text) {
        return NO;
    }

    if (rangeOut != NULL) {
        *rangeOut = range;
    }
    if (textOut != NULL) {
        *textOut = text;
    }

    return YES;
}
