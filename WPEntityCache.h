//
//  WPEntityCache.h
//  WPChat
//
//  Created by Leon Peng on 13-10-31.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface WPEntityCache : NSObject {
    NSMutableDictionary     *_propertyCache;
}

+ (WPEntityCache *)currentCache;
- (id)value:(NSString *)key;
- (void)save:(NSString *)key value:(id)obj;
- (void)clear;

@end
