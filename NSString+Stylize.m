#import "NSString+Stylize.h"

@implementation NSString (Stylize)

+ (NSString *)stylizeText:(NSString *)text withMap:(NSDictionary *)map {
    NSUInteger length = text.length;
    NSMutableString *stylized = [NSMutableString stringWithCapacity:length];
    
    [text enumerateSubstringsInRange:NSMakeRange(0, length) options:NSStringEnumerationByComposedCharacterSequences
        usingBlock: ^(NSString *key, NSRange inSubstringRange, NSRange inEnclosingRange, BOOL *outStop) {
        if ([map objectForKey:key]) {
            [stylized appendString:map[key]];
        } else {
            [stylized appendString:key];
        }
    }];

    return stylized;
}

+ (NSString *)stylizeTextSpongebob:(NSString *)text {
    NSCharacterSet *letters = [NSCharacterSet letterCharacterSet];
    NSUInteger length = text.length;
    NSMutableString *stylized = [NSMutableString stringWithCapacity:length];
    unichar buffer[length + 1];

    [text getCharacters:buffer range:NSMakeRange(0, length)];

    BOOL shouldUppercase = YES;
    for (int i = 0; i < length; i++) {
        if ([letters characterIsMember:buffer[i]]) {
            if (shouldUppercase) {
                [stylized appendString:[[NSString stringWithCharacters:&buffer[i] length:1] localizedUppercaseString]];
            } else {
                [stylized appendString:[[NSString stringWithCharacters:&buffer[i] length:1] localizedLowercaseString]];
            }
            shouldUppercase = !shouldUppercase;
        } else {
            [stylized appendFormat:@"%C", buffer[i]];
        }
    }

    return stylized;
}

+ (NSString *)stylizeText:(NSString *)text withCombiningChar:(NSString *)combiningChar {
    NSUInteger length = text.length;
    NSMutableString *stylized = [NSMutableString stringWithCapacity:length * combiningChar.length];
    unichar buffer[length + 1];

    [text getCharacters:buffer range:NSMakeRange(0, length)];

    for (int i = 0; i < length; i++) {
        [stylized appendFormat:@"%c%@", buffer[i], combiningChar];
    }

    return stylized;
}

+ (NSString *)stylizeText:(NSString *)text withStyle:(NSDictionary *)style {
    if (style[@"map"]) {
        return [NSString stylizeText:text withMap:style[@"map"]];
    } else if (style[@"combine"]) {
        return [NSString stylizeText:text withCombiningChar:style[@"combine"]];
    } else if ([style[@"function"] isEqualToString:@"spongebob"]) {
        return [NSString stylizeTextSpongebob:text];
    }

    return nil;
}

+ (NSString *)stylizeTextSpongebobActive:(NSString *)text counter:(int *)counter {
    NSString *stylized;
    *counter += 1;

    stylized = (*counter % 2) ? [text localizedUppercaseString] : [text localizedLowercaseString];
    return stylized;
}

@end