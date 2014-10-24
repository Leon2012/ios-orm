//
//  WPEntityManager.m
//  WPChat
//
//  Created by Leon Peng on 13-10-31.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import "WPEntityManager.h"
#import "WPSandbox.h"
#import "FMDatabaseAdditions.h"
#import "NSString+Util.h"

@interface WPEntity()
- (void)setRowId:(sqlite_int64)rowId;
@end

@interface WPEntityCache()
- (id)initWithEntity:(NSString *)entityName InManager:(WPEntityManager *)entityManager;
- (id)initWithEntity:(NSString *)entityName whereStatement:(NSString *)whereStatement whereBinds:(NSArray *)whereBinds InManager:(WPEntityManager *)entityManager;
+ (WPEntityQuery *)queryForEntity:(NSString *)entityName InManager:(WPEntityManager *)entityManager;
@end

static NSMutableDictionary * databaseTypeMap = nil;

@interface WPEntityManager()
- (BOOL)open;
- (void)close;
//- (WPEntityQuery *)createQueryWithWql:(NSString *)wql;
@end

@implementation WPEntityManager
@synthesize db = _db;

+ (void)initialize
{
    databaseTypeMap = [[NSMutableDictionary dictionaryWithObjectsAndKeys:
                        @"text", @"NSString",
                        @"integer", @"NSInteger",
                        @"integer", @"NSNumber",
                        @"double", @"NSDate",
                        @"integer", @"i",
                        @"integer", @"c",
                        @"double", @"d",
                        @"double", @"f",
                        nil
                        ] retain];
}

- (void)dealloc
{
    if (_db != nil){
        [_db close];
        _R(_db);
    }
    _R(_dbFileName);
    _R(_entities);
    [super dealloc];
}

- (id)initWithDatabaseFileName:(NSString *)dbFileName
{
    self = [super init];
    if (self) {
        _entities = [[NSMutableArray alloc] init];
        _dbFileName = [dbFileName retain];
        _db = [FMDatabase databaseWithPath:[self dbFileFullPath]];
        NSLog(@"db path :  %@", [self dbFileFullPath]);
        [_db retain];
        [_db setLogsErrors:YES];
        if (_db == nil){
            [self dealloc];
            return nil;
        }
        if (![_db open]) {
            [self dealloc];
            return nil;
        }
        [_db setShouldCacheStatements:YES];
    }
    return self;
}

- (NSString *)dbFileFullPath
{
    return [[WPSandbox docPath] stringByAppendingPathComponent:_dbFileName];
}

- (BOOL)open
{
    
    return [_db open];
}

- (void)close
{
    [_db close];
}

- (BOOL)registerEntity:(Class)class
{
    if ([class isSubclassOfClass:[WPEntity class]]) {
        NSString *entityName = [NSString stringWithUTF8String:class_getName(class)] ;
        if (![_entities containsObject:entityName]) {
            WPEntity *entity = [[class alloc] initWithEntityManager:self];
            //entity.entityManager = self;
            if (![entity isCreated]) {
                BOOL isOK = [entity create];
                if (!isOK) {
                    return NO;
                }else{
                    [_entities addObject:entityName];
                    return YES;
                }
            }else{
                [_entities addObject:entityName];
                return YES;
            }
        }
    }
    return NO;
}

- (int)getEntityRecordCount:(Class)class
{
    int total = 0;
    if ([class isSubclassOfClass:[WPEntity class]]) {
        NSString *entityName = [NSString stringWithUTF8String:class_getName(class)] ;
        NSString *tableName = camel2underline(entityName);
        
        if (![self tableIsExist:tableName]) {
            NSLog(@"数据表 %@ 不存在!", tableName);
        }else{
            NSString *sql = [NSString stringWithFormat:@" SELECT count(*) as total FROM  %@ ", tableName];
            FMResultSet *resultSet = [self query:sql withArgs:nil];
            if (resultSet != nil) {
                if ([resultSet next]) {
                    total = [resultSet intForColumn:@"total"];
                }
                [resultSet close];
            }
        }
    }
    return total;
}


- (BOOL)tableIsExist:(NSString *)tableName
{
    return [_db tableExists:tableName];
}

- (BOOL)execute:(NSString *)sql
{
    NSLog(@"sql : %@", sql);
    return [_db executeUpdate:sql];
}

- (BOOL)execute:(NSString *)sql withArgs:(NSArray *)args
{
    NSLog(@"sql : %@", sql);
    return [_db executeUpdate:sql withArgumentsInArray:args];
}

- (FMResultSet *)query:(NSString *)sql withArgs:(NSArray *)args
{
    FMResultSet *resultSet;
    if (args != NULL) {
        resultSet = [_db executeQuery:sql withArgumentsInArray:args];
    }else{
        resultSet = [_db executeQuery:sql];
    }
    return resultSet;
}


- (int)lastErrCode
{
    return [_db lastErrorCode];
}

- (NSString *)lastErrMsg
{
    return [_db lastErrorMessage];
}

- (NSError *)lastError
{
    return [_db lastError];
}

- (sqlite_int64)lastInsertRowId
{
    return [_db lastInsertRowId];
}

+ (NSString *) prop2field:(NSString *)propType
{
    return [databaseTypeMap objectForKey:propType];
}

+ (BOOL)typeIsAllow:(NSString *)propType
{
    NSArray *allKeys = [databaseTypeMap allKeys];
    return [allKeys containsObject:propType];
}

/**
 *  解析wql
 *
 *  @param wql, example: FROM entityName WHERE a = :a AND b = :b
 *
 *  @return entity query
 */

- (WPEntityQuery *)createQuery:(NSString *)wql
{
    if (wql == Nil) {
        return nil;
    }
    NSString *pattern = @"(\\s+)";
    NSString *wql1 = [wql stringByReplacingOccurrencesOfString:pattern withString:@" "];
    NSString *wql2 = [wql1 trim];
    NSArray *wqls = [wql2 componentsSeparatedByString:@" "];
    if ([wqls count] < 2) {
        NSLog(@"没有表名!");
        return nil;
    }
    //NSString *from = [wqls objectAtIndex:0];
    NSString *entityName = [wqls objectAtIndex:1];
    
    NSString *tableName = camel2underline(entityName);
    if (![self tableIsExist:tableName]) {
        NSLog(@"数据表不存在，尝试创建!");
        WPEntity *entity = [[NSClassFromString(entityName) alloc] initWithEntityManager:self];
        if (![entity create]) {
            NSLog(@"创建 %@ 表失败!", entityName);
            return nil;
        }
    }
    
    //if ([_entities indexOfObject:entityName] == NSNotFound) {
    //    NSLog(@"没有表名!");
    //    return nil;
    //}
    
    NSString *where;
    //NSMutableArray *whereKeys = [NSMutableArray array];
    NSMutableArray *whereBinds = [NSMutableArray array];
    NSMutableString *whereStatement = [NSMutableString string];
    
    if ([wqls count] > 2) {
        where = [wqls objectAtIndex:2];
        if (![@"WHERE" isEqualToString:[where uppercaseString]]) {
            NSLog(@"没有where语句!");
            return nil;
        }
        
        for (int i=3; i<[wqls count]; i++) {
            NSString *s = [wqls objectAtIndex:i];
            if ([s hasPrefix:@":"]) {
                NSString *whereBind = s;
                [whereBinds addObject:whereBind];
                [whereStatement appendFormat:@" %@ ", @"?"];
            }else{
                [whereStatement appendFormat:@" %@ ", s];
            }
        }
        
        
        /*
        int andCount = [wqls count] - 3 + 1;
        if ((andCount%4) != 0 ) {
            NSLog(@"查询参数不匹配!");
            return nil;
        }
        int startIndex = 3;
        int step = 4;
        while (startIndex < [wqls count]) {
            NSString *whereKey = [wqls objectAtIndex:startIndex];
            NSString *equal = [wqls objectAtIndex:startIndex + 1];
            NSString *whereBind = [wqls objectAtIndex:startIndex + 2];
            NSString *and;
            if ((startIndex + 3) < [wqls count]) {
                and = [wqls objectAtIndex:startIndex + 3];
            }else{
                and = @"and";
            }
            
            if (![@"AND" isEqualToString:[and uppercaseString]]) {
                NSLog(@"没有AND语句!");
                return nil;
            }
            
            [whereKeys addObject:whereKey];
            [whereBinds addObject:whereBind];
            startIndex += step;
        }
         
        
        if ([whereKeys count] != [whereBinds count]) {
            NSLog(@"查询参数不匹配!");
            return nil;
        }
         */
    }
    
    //WPEntity *entity = [[NSClassFromString(entityName) alloc] initWithEntityManager:self];
    
    if (([whereStatement length]) > 0 && ([whereBinds count] > 0)) {
        return [[[WPEntityQuery alloc] initWithEntity:entityName
                                            whereStatement:[NSString stringWithString:whereStatement]
                                           whereBinds:[NSArray arrayWithArray:whereBinds]
                                            InManager:self] autorelease];
    }else {
        return [WPEntityQuery queryForEntity:entityName InManager:self];
    }
    
    return nil;
}

@end
