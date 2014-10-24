//
//  WPEntityQuery.h
//  WPChat
//
//  Created by Leon Peng on 13-11-1.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "WPEntityCache.h"

@class WPEntity;
@class WPEntityManager;
@class FMResultSet;
@interface WPEntityQuery : NSObject {
    NSString            *_entityName;
    WPEntityManager     *_entityManager;
    NSArray             *_whereKeys;
    NSArray             *_whereBinds;
    NSMutableArray      *_whereValues;
    NSString            *_whereStatement;
    int                 _firstResult;
    int                 _maxResults;
    BOOL                _cacheable;
}

- (int)totalCount;
- (NSArray *)list;
- (NSObject *)uniqueResult;
- (void)setParameterValue:(id)paramValue forName:(NSString *)paramName;
- (void)setParameterValue:(id)paramValue forIndex:(int)paramIndex;

- (void)setFirstResult:(int)firstResult;
- (void)setMaxResults:(int)maxResults;
//- (void)setCacheable:(BOOL)cacheable;

@end
