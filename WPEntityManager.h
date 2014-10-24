//
//  WPEntityManager.h
//  WPChat
//
//  Created by Leon Peng on 13-10-31.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import <Foundation/Foundation.h>
#include "objc/runtime.h"
#include "FMDatabase.h"
#import "WPEntity.h"
#import "WPEntityQuery.h"

@protocol WPEntityManagerDelegate;

@interface WPEntityManager : NSObject {
    FMDatabase          *_db;
    NSString            *_dbFileName;
    NSMutableArray      *_entities;
}

@property (readonly, nonatomic) FMDatabase  *db;

- (id)initWithDatabaseFileName:(NSString *)dbFileName;
- (BOOL)tableIsExist:(NSString *)tableName;
- (BOOL)execute:(NSString *)sql;
- (BOOL)execute:(NSString *)sql withArgs:(NSArray *)args;
- (FMResultSet *)query:(NSString *)sql withArgs:(NSArray *)args;

/**
 *  创建数据表
 *
 *  @param class entity class
 *
 *  @return YES 创建成功，NO 创建失败
 */
- (BOOL)registerEntity:(Class)class;

/**
 *  获取entity的总计录数
 *
 *  @param class entity class
 *
 *  @return 总条数
 */
- (int)getEntityRecordCount:(Class)class;

/**
 *  创建WPEntityQuery对像
 *
 *  @param wql 语句
 *
 *  @return WPEntityQuery Instance
 */
- (WPEntityQuery *)createQuery:(NSString *)wql;

- (int)lastErrCode;
- (NSString *)lastErrMsg;
- (NSError *)lastError;
- (sqlite_int64)lastInsertRowId;

+ (NSString *) prop2field:(NSString *)propType;
+ (BOOL)typeIsAllow:(NSString *)propType;
@end



@protocol WPEntityManagerDelegate <NSObject>



@end