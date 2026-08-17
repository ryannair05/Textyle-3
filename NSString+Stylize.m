#import "NSString+Stylize.h"

@implementation NSString (Stylize)

+ (NSString *)stylizeText:(NSString *)text withMap:(NSDictionary *)map {
    if (text.length == 0 || map.count == 0) {
        return text;
    }

    NSMutableString *stylized = [NSMutableString stringWithCapacity:text.length];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *key,
                                       NSRange substringRange,
                                       NSRange enclosingRange,
                                       BOOL *stop) {
        NSString *replacement = map[key];
        [stylized appendString:replacement ?: key];
    }];
    return stylized;
}

+ (NSString *)stylizeTextSpongebob:(NSString *)text {
    int counter = 0;
    return [self stylizeTextSpongebobActive:text counter:&counter];
}

+ (NSString *)stylizeText:(NSString *)text withCombiningChar:(NSString *)combiningCharacter {
    if (text.length == 0 || combiningCharacter.length == 0) {
        return text;
    }

    NSMutableString *stylized = [NSMutableString stringWithCapacity:text.length];
    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring,
                                       NSRange substringRange,
                                       NSRange enclosingRange,
                                       BOOL *stop) {
        [stylized appendString:substring];
        [stylized appendString:combiningCharacter];
    }];
    return stylized;
}

+ (NSString *)stylizeText:(NSString *)text withStyle:(NSDictionary *)style {
    if (style[@"map"]) {
        return [self stylizeText:text withMap:style[@"map"]];
    }
    if (style[@"combine"]) {
        return [self stylizeText:text withCombiningChar:style[@"combine"]];
    }
    if ([style[@"function"] isEqualToString:@"spongebob"]) {
        return [self stylizeTextSpongebob:text];
    }
    return nil;
}

+ (NSString *)stylizeTextSpongebobActive:(NSString *)text counter:(int *)counter {
    if (text.length == 0) {
        return text;
    }

    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    NSMutableString *stylized = [NSMutableString stringWithCapacity:text.length];
    __block int currentCounter = *counter;

    [text enumerateSubstringsInRange:NSMakeRange(0, text.length)
                             options:NSStringEnumerationByComposedCharacterSequences
                          usingBlock:^(NSString *substring,
                                       NSRange substringRange,
                                       NSRange enclosingRange,
                                       BOOL *stop) {
        if ([substring rangeOfCharacterFromSet:letters].location == NSNotFound) {
            [stylized appendString:substring];
            return;
        }

        currentCounter += 1;
        [stylized appendString:(currentCounter % 2)
            ? substring.localizedUppercaseString
            : substring.localizedLowercaseString];
    }];

    *counter = currentCounter;
    return stylized;
}

@end
