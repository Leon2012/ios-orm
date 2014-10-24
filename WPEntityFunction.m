//
//  WPEntityFunction.m
//  WPChat
//
//  Created by Leon Peng on 13-10-31.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import "WPEntityFunction.h"


NSString *camel2underline(NSString *str)
{
    NSMutableString *sb = [NSMutableString string];
    for (int i=0; i < [str length]; i++) {
        unichar c = [str characterAtIndex:i];
        NSString *s = [NSString stringWithCharacters:&c length:1];
        BOOL isUppercase = [[NSCharacterSet uppercaseLetterCharacterSet] characterIsMember:c];
        if (isUppercase && (i != 0)) {
            [sb appendString:@"_"];
            [sb appendString:[s lowercaseString]];
        }else{
            [sb appendString:[s lowercaseString]];
        }
    }
    return [NSString stringWithString:sb];
}