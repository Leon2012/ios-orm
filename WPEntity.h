//
//  WPEntity.h
//  WPChat
//
//  Created by Leon Peng on 13-10-31.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "objc/runtime.h"
#import "WPEntityCache.h"
#import "WPEntityManager.h"
#import "WPEntityFunction.h"

@class WPEntityManager;
@interface WPEntity : NSObject {
    WPEntityManager *_entityManager;
    sqlite_int64    _rowId;
}

+ (WPEntity *)entityInManager:(WPEntityManager *)entityManager;
- (id)initWithEntityManager:(WPEntityManager *)entityManager;

- (NSString *)primaryKey;
- (NSString *)tableName;
- (NSDictionary *)properties;//字段对应的Class中的属性
- (NSDictionary *)columns; //字段对应的数据表中的column name
- (NSDictionary *)fields;//字段对应的数据表中的column type
- (NSDictionary *)tableProperties;

- (BOOL)save;
- (BOOL)create;
- (BOOL)remove;
- (BOOL)update;
- (BOOL)isCreated;

- (sqlite_int64)rowId;

@end
