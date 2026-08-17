#import "../Tweak.h"

#import "../NSString+Stylize.h"
#import "../UIKitPrivate.h"
#import "../TXTStyleManager.h"

static __thread NSUInteger TXTInputStateGeneration = 0;
static __thread int TXTSpongebobCounter = 0;

%group TXTKeyboardInput

%hook UIKBInputDelegateManager

- (void)insertText:(NSString *)text updateInputSource:(BOOL)updateInputSource {
    if (TXTInputStateGeneration != TXTLiveStateGeneration) {
        TXTInputStateGeneration = TXTLiveStateGeneration;
        TXTSpongebobCounter = 0;
    }

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject] input observed process=%@ active=%@ length=%lu",
          NSProcessInfo.processInfo.processName,
          TXTLiveTypingActive ? @"YES" : @"NO",
          (unsigned long)text.length);
#endif

    if (!TXTLiveTypingActive || text.length == 0) {
        %orig(text, updateInputSource);
        return;
    }

    NSDictionary *style = TXTStyleManager.sharedManager.activeStyle;
    NSString *replacement = [style[@"function"] isEqualToString:@"spongebob"]
        ? [NSString stylizeTextSpongebobActive:text
                                       counter:&TXTSpongebobCounter]
        : [NSString stylizeText:text withStyle:style];

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject] transformed input process=%@ original=%@ replacement=%@",
          NSProcessInfo.processInfo.processName,
          text,
          replacement ?: text);
#endif

    %orig(replacement ?: text, updateInputSource);
}

%end
%end

void TXTInitializeKeyboardInputHooks(void) {
    %init(TXTKeyboardInput);

#if defined(TEXTYLE_SIMJECT)
    NSLog(@"[Textyle][Simject] keyboard input hook installed process=%@",
          NSProcessInfo.processInfo.processName);
#endif
}
