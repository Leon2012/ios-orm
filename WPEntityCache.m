//
//  WPEntityCache.m
//  WPChat
//
//  Created by Leon Peng on 13-10-31.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import "WPEntityCache.h"

@implementation WPEntityCache

+ (WPEntityCache *)currentCache
{
    static WPEntityCache *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[WPEntityCache alloc] init];
    });
    return sharedInstance;
}

- (void)dealloc
{
    _R(_propertyCache);
    [super dealloc];
}


- (id)init
{
    self = [super init];
    if (self) {
        _propertyCache = [[NSMutableDictionary alloc] init];
    }
    return self;
}

- (id)value:(NSString *)key
{
    return [_propertyCache objectForKey:key];
}

- (void)save:(NSString *)key value:(id)obj
{
    [_propertyCache setObject:obj forKey:key];
}

- (void)clear
{
    [_propertyCache removeAllObjects];
}

@end
