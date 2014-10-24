//
//  WPEntityQuery.m
//  WPChat
//
//  Created by Leon Peng on 13-11-1.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import "WPEntityQuery.h"
#import "WPEntity.h"
#import "WPEntityManager.h"
#import "FMDatabase.h"

@interface WPEntity()
- (void)setRowId:(sqlite_int64)rowId;
@end

@interface WPEntityQuery()



@property (retain, nonatomic) NSString          *entityName;
@property (retain, nonatomic) WPEntityManager   *entityManager;
@property (retain, nonatomic) NSArray           *whereKeys;
@property (retain, nonatomic) NSArray           *whereBinds;
@property (retain, nonatomic) NSString          *whereStatement;

- (void)initParamValues;
- (NSString *)genSQL;
@end



@implementation WPEntityQuery
@synthesize entityName = _entityName, entityManager = _entityManager, whereKeys = _whereKeys, whereBinds = _whereBinds;
@synthesize whereStatement = _whereStatement;

- (void)dealloc
{
    _R(_entityName);
    _R(_entityManager);
    _R(_whereKeys);
    _R(_whereBinds);
    _R(_whereValues);
    _R(_whereStatement);
    [super dealloc];
}

+ (WPEntityQuery *)queryForEntity:(NSString *)entityName InManager:(WPEntityManager *)entityManager
{
    WPEntityQuery *query = [[WPEntityQuery alloc] initWithEntity:entityName InManager:entityManager];
    return [query autorelease];
}

- (id)initWithEntity:(NSString *)entityName InManager:(WPEntityManager *)entityManager
{
    return [self initWithEntity:entityName whereStatement:nil whereBinds:nil InManager:entityManager];
}

- (id)initWithEntity:(NSString *)entityName whereStatement:(NSString *)whereStatement whereBinds:(NSArray *)whereBinds InManager:(WPEntityManager *)entityManager
{
    self = [super init];
    if (self) {
        self.entityName = entityName;
        self.entityManager = entityManager;
        //self.whereKeys = whereKeys;
        self.whereBinds = whereBinds;
        self.whereStatement = whereStatement;
        
        if (self.whereBinds != nil && self.whereStatement != nil) {
            [self initParamValues];
        }
        _firstResult = 0;
        _maxResults = 0;
        _cacheable = NO;
    }
    return self;
}

- (void)initParamValues
{
    _whereValues = [[NSMutableArray alloc] initWithCapacity:self.whereBinds.count];
    for (int i=0; i<self.whereBinds.count; i++) {
        [_whereValues addObject:[NSNull null]];
    }
}

- (void)setParameterValue:(id)paramValue forName:(NSString *)paramName
{
    if (_whereValues != nil && [_whereValues count] > 0) {
        if ([paramName hasPrefix:@":"]) {
            paramName = [paramName substringFromIndex:1];
        }
        int index = [_whereBinds indexOfObject:[@":" stringByAppendingString:paramName]];
        if (index != NSNotFound) {
            [self setParameterValue:paramValue forIndex:index];
        }
    }
}

- (void)setParameterValue:(id)paramValue forIndex:(int)paramIndex
{
    if (_whereValues != nil && [_whereValues count] > paramIndex) {
        [_whereValues replaceObjectAtIndex:paramIndex withObject:paramValue];
    }
}

- (void)setFirstResult:(int)firstResult
{
    _firstResult = firstResult;
}

- (void)setMaxResults:(int)maxResults
{
    _maxResults = maxResults;
}

- (void)setCacheable:(BOOL)cacheable
{
    _cacheable = cacheable;
}

- (NSString *)genSQL
{
    NSMutableString *sb = [NSMutableString string];
    NSString *tableName = camel2underline(_entityName);
    [sb appendString:[NSString stringWithFormat:@" SELECT rowid, * FROM %@  ", tableName]];
    if (self.whereStatement != nil) {
        [sb appendString:@" WHERE "];
        [sb appendFormat:@" %@ ", self.whereStatement];
    }
    
    if (_firstResult >= 0 && _maxResults > 0) {
        [sb appendFormat:@" LIMIT %d, %d ", _firstResult, _maxResults];
    }
    
    /*
    if (self.whereKeys != nil && _whereValues != nil && (self.whereKeys.count == [_whereValues count])) {
        [sb appendString:@" WHERE 1 = 1 "];
        for (int i=0; i<self.whereKeys.count; i++) {
            NSString *propName = [self.whereKeys objectAtIndex:i];
            NSString *fieldName = camel2underline(propName);
            //id fieldValue = [_whereValues objectAtIndex:i];
            [sb appendFormat:@" AND %@ = ?  ", fieldName];
        }
    }
     */
    NSString *sql = [NSString stringWithString:sb];
    return sql;
}

- (int)totalCount
{
    int total = 0;
    NSMutableString *sb = [NSMutableString string];
    NSString *tableName = camel2underline(_entityName);
    [sb appendString:[NSString stringWithFormat:@" SELECT count(*) as total FROM %@  ", tableName]];
    if (self.whereStatement != nil) {
        [sb appendString:@" WHERE "];
        [sb appendFormat:@" %@ ", self.whereStatement];
    }
    NSString *sql = [NSString stringWithString:sb];
    FMResultSet *resultSet = [_entityManager query:sql withArgs:_whereValues];
    if (resultSet != nil) {
        if ([resultSet next]) {
            total = [resultSet intForColumn:@"total"];
        }
        [resultSet close];
    }
    return total;
}

- (NSArray *)list
{
    NSMutableArray *results  = NULL;
    NSString *sql = [self genSQL];
    FMResultSet *resultSet = [_entityManager query:sql withArgs:_whereValues];
    if (resultSet != NULL) {
        results = [NSMutableArray array];
        WPEntity *entity;
        while ([resultSet next]) {
            entity = [[NSClassFromString(_entityName) alloc] initWithEntityManager:_entityManager];
            [entity setRowId:[resultSet longLongIntForColumn:@"rowid"]];
            
            NSDictionary *properties = [entity properties];
            //NSLog(@"properties : %@", properties);
            NSDictionary *columns = [entity columns];
            //NSLog(@"columns : %@", columns);
            
            NSArray *allKeys = [properties allKeys];
            for (int i=0; i<[allKeys count]; i++) {
                NSString *propName = [allKeys objectAtIndex:i];
                NSString *propType = [properties objectForKey:propName];
                NSString *fieldName = [columns objectForKey:propName];
                NSString *v1 = [resultSet stringForColumn:fieldName];
                id v2 = [self convertValue:v1 withFieldType:propType];
                
                [entity setValue:v2 forKey:propName];
            }
            
            [results addObject:entity];
            [entity release];
        }
        [resultSet close];
    }
    return results;
}

- (NSObject *)uniqueResult
{
    WPEntity *entity = Nil;
    _firstResult = 0;
    _maxResults = 0;
    NSString *sql = [self genSQL];
    FMResultSet *resultSet = [_entityManager query:sql withArgs:_whereValues];
    if (resultSet != NULL) {
        if ([resultSet next]) {
            entity = [[NSClassFromString(_entityName) alloc] initWithEntityManager:_entityManager];
            [entity setRowId:[resultSet longLongIntForColumn:@"rowid"]];
            NSDictionary *properties = [entity properties];
            //NSLog(@"properties : %@", properties);
            NSDictionary *columns = [entity columns];
            //NSLog(@"columns : %@", columns);
            
            NSArray *allKeys = [properties allKeys];
            for (int i=0; i<[allKeys count]; i++) {
                NSString *propName = [allKeys objectAtIndex:i];
                NSString *propType = [properties objectForKey:propName];
                NSString *fieldName = [columns objectForKey:propName];
                NSString *v1 = [resultSet stringForColumn:fieldName];
                id v2 = [self convertValue:v1 withFieldType:propType];
                
                [entity setValue:v2 forKey:propName];
            }
        }
        [resultSet close];
    }
    return [entity autorelease];
}

- (id)convertValue:(NSString *)fieldValue withFieldType:(NSString *)fieldType
{
    if ([fieldValue isKindOfClass:[NSNull class]]) {
        return fieldValue;
    }
    if ([@"NSString" isEqualToString:fieldType]) {
        return fieldValue;
    }else if ([@"d" isEqualToString:fieldType]) {
        NSNumber *aFieldValue = [NSNumber numberWithDouble:[fieldValue doubleValue]];
        return aFieldValue;
    }else if ([@"f" isEqualToString:fieldType]){
        NSNumber *aFieldValue = [NSNumber numberWithFloat:[fieldValue floatValue]];
        return aFieldValue;
    }else if ([@"c" isEqualToString:fieldType]) {
        NSNumber *aFieldValue = [NSNumber numberWithBool:[fieldValue boolValue]];
        return aFieldValue;
    }else if ([@"i" isEqualToString:fieldType]) {
        NSNumber *aFieldValue = [NSNumber numberWithInteger:[fieldValue integerValue]];
        return aFieldValue;
    }else if ([@"NSDate" isEqualToString:fieldType]) {
        if ([fieldValue isKindOfClass:[NSDate class]]) {
            return fieldValue;
        }else{
            NSDate *date = [NSDate dateWithTimeIntervalSince1970:[fieldValue doubleValue]];
            if (date) {
                return date;
            }
        }
    }
    return [NSNull null];
}


@end
