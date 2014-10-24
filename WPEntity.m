//
//  WPEntity.m
//  WPChat
//
//  Created by Leon Peng on 13-10-31.
//  Copyright (c) 2013年 Leon Peng. All rights reserved.
//

#import "WPEntity.h"
#import "WPException.h"

@interface WPEntity()
@property (retain, nonatomic) WPEntityManager *entityManager;
- (NSString *)buildQueryWithType:(NSString *)type;
- (id)convertValue:(NSString *)fieldValue withFieldType:(NSString *)fieldType;
@end


@implementation WPEntity

@synthesize entityManager = _entityManager;

+ (WPEntity *)entityInManager:(WPEntityManager *)entityManager
{
    WPEntity *entity = [[[self class] alloc] init];
    entity.entityManager = entityManager;
    return entity;
}

- (void)dealloc
{
    _R(_entityManager);
    [super dealloc];
}

- (id)initWithEntityManager:(WPEntityManager *)entityManager
{
    self = [super init];
    if (self) {
        self.entityManager = entityManager;
    }
    return self;
}

- (NSString *)primaryKey
{
    return nil;
}

- (NSString *)tableName
{
    NSString *tableName = [NSString stringWithFormat:@"%s", class_getName([self class])];
    return camel2underline(tableName);
}

- (void)setRowId:(sqlite_int64)rowId
{
    _rowId = rowId;
}

- (sqlite_int64)rowId
{
    return _rowId;
}

- (NSDictionary *)properties
{
    NSString *key = [self tableName];
    NSDictionary *theProps = [[WPEntityCache currentCache] value:key];
    
    if (theProps == nil) {
        theProps = [[self class] loadProperties];
        [[WPEntityCache currentCache] save:key value:theProps];
    }
    return theProps;
}

- (NSDictionary *)columns
{
    NSDictionary *properties = [self properties];
    NSMutableDictionary *columns = [NSMutableDictionary dictionary];
    NSArray *allKeys = [properties allKeys];
    for (int i=0; i<[allKeys count]; i++) {
        NSString *propName = [allKeys objectAtIndex:i];
        //NSString *propType = [properties objectForKey:propName];
        NSString *columnName = camel2underline(propName);
        [columns setObject:columnName forKey:propName];
    }
    return [NSDictionary dictionaryWithDictionary:columns];
}

- (NSDictionary *)fields
{
    NSDictionary *properties = [self properties];
    NSMutableDictionary *columns = [NSMutableDictionary dictionary];
    NSArray *allKeys = [properties allKeys];
    for (int i=0; i<[allKeys count]; i++) {
        NSString *propName = [allKeys objectAtIndex:i];
        NSString *propType = [properties objectForKey:propName];
        NSString *columnType = [WPEntityManager prop2field:propType];
        //WPLog(@"prop type : %@ columnType %@", propType, columnType);
        if (columnType != nil) {
            [columns setObject:columnType forKey:propName];
        }
    }
     return [NSDictionary dictionaryWithDictionary:columns];
}

- (NSDictionary *)tableProperties
{
    NSDictionary *properties = [self properties];
    NSMutableDictionary *tableProperties = [NSMutableDictionary dictionary];
    NSArray *allKeys = [properties allKeys];
    for (int i=0; i<[allKeys count]; i++) {
        NSString *propName = [allKeys objectAtIndex:i];
        NSString *propType = [properties objectForKey:propName];
        NSString *fieldName = camel2underline(propName);
        NSString *fieldType = [WPEntityManager prop2field:propType];
        if (fieldType != nil) {
            [tableProperties setObject:fieldType forKey:fieldName];
        }
    }
    return [NSDictionary dictionaryWithDictionary:tableProperties];
}

- (BOOL)create
{
    NSMutableString *query = [NSMutableString string];
    [query appendString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ( ", [self tableName]]];
    NSDictionary *tablePropreties = [self tableProperties];
    NSArray *allKeys = [tablePropreties allKeys];
    for (int i=0; i<[allKeys count]; i++) {
        NSString *fieldName = [allKeys objectAtIndex:i];
        NSString *fieldType = [tablePropreties objectForKey:fieldName];
        if (i == ([allKeys count] - 1)) {
            [query appendString:[NSString stringWithFormat:@" %@ %@ ", fieldName, fieldType]];
        }else{
            [query appendString:[NSString stringWithFormat:@" %@ %@ , ", fieldName, fieldType]];
        }
    }
    if ([self primaryKey] != nil) {
        NSString *primaryKey = [self primaryKey];
        [query appendString:[NSString stringWithFormat:@" , PRIMARY KEY (%@) ", camel2underline(primaryKey)]];
    }
    [query appendString:@" );"];
    
    return [_entityManager execute:[NSString stringWithString:query]];
}

- (BOOL)save
{
    NSMutableString *query = [NSMutableString string];
    [query appendString:[NSString stringWithFormat:@"INSERT INTO %@ ( ", [self tableName]]];
    NSDictionary *columns = [self columns];
    NSDictionary *properties = [self properties];
    NSArray *allKeys = [columns allKeys];
    
    NSMutableArray *fieldNames = [NSMutableArray array];
    NSMutableArray *bindValues = [NSMutableArray array];
    NSMutableArray *fieldValues = [NSMutableArray array];
    
    for (int i=0; i < [allKeys count]; i++) {
        NSString *propName = [allKeys objectAtIndex:i];
        NSString *fieldName = [columns objectForKey:propName];
        NSString *fieldType = [properties objectForKey:propName];
        
        [fieldNames addObject:fieldName];
        [bindValues addObject:@"?"];
        NSString *fieldValue = [self valueForKey:propName];
        [fieldValues addObject:[self convertValue:fieldValue withFieldType:fieldType]];
    }
    [query appendString:[fieldNames componentsJoinedByString:@","]];
    [query appendString:@" ) VALUES ( "];
    [query appendString:[bindValues componentsJoinedByString:@","]];
    [query appendString:@" ); "];
    
    return [_entityManager execute:[NSString stringWithString:query] withArgs:fieldValues];
}

- (BOOL)remove
{
    if ([self primaryKey] == nil && _rowId <= 0) {
        @throw [WPException exceptionWithObject:self reason:@"Not found any primary key!"];
    }
    
    NSMutableString *query = [NSMutableString string];
    [query appendString:[NSString stringWithFormat:@"DELETE FROM %@ ", [self tableName]]];
    NSMutableArray *fieldValues = [NSMutableArray array];
    if ([self primaryKey] != Nil) {
        NSString *primaryKey = [self primaryKey];
        [query appendString:[NSString stringWithFormat:@" WHERE %@ = ?", camel2underline(primaryKey)]];
        NSString *fieldValue = [self valueForKey:primaryKey];
        NSString *fieldType = [[self properties] objectForKey:primaryKey];
        [fieldValues addObject:[self convertValue:fieldValue withFieldType:fieldType]];
    }else{
        [query appendString:[NSString stringWithFormat:@" WHERE rowid = ?"]];
        [fieldValues addObject:[NSNumber numberWithLongLong:_rowId]];
    }
    return [_entityManager execute:[NSString stringWithString:query] withArgs:fieldValues];;
}

- (BOOL)update
{
    if ([self primaryKey] == nil && _rowId <= 0) {
        @throw [WPException exceptionWithObject:self reason:@"Not found any primary key!"];
    }
    
    NSMutableString *query = [NSMutableString string];
    [query appendString:[NSString stringWithFormat:@"UPDATE %@ SET  ", [self tableName]]];
    NSDictionary *columns = [self columns];
    NSDictionary *properties = [self properties];
    NSArray *allKeys = [columns allKeys];
    
    NSMutableArray *bindValues = [NSMutableArray array];
    NSMutableArray *fieldValues = [NSMutableArray array];
    
    for (int i=0; i < [allKeys count]; i++) {
        NSString *propName = [allKeys objectAtIndex:i];
        NSString *fieldName = [columns objectForKey:propName];
        NSString *fieldType = [properties objectForKey:propName];
        
        [bindValues addObject:[NSString stringWithFormat:@"%@ = ?", fieldName]];
        NSString *fieldValue = [self valueForKey:propName];
        [fieldValues addObject:[self convertValue:fieldValue withFieldType:fieldType]];
    }
    [query appendString:[bindValues componentsJoinedByString:@","]];
    
    if ([self primaryKey] != Nil) {
        NSString *primaryKey = [self primaryKey];
        [query appendString:[NSString stringWithFormat:@" WHERE %@ = ?", camel2underline(primaryKey)]];
        NSString *fieldValue = [self valueForKey:primaryKey];
        NSString *fieldType = [[self properties] objectForKey:primaryKey];
        [fieldValues addObject:[self convertValue:fieldValue withFieldType:fieldType]];
    }else{
        [query appendString:[NSString stringWithFormat:@" WHERE rowid = ?"]];
        [fieldValues addObject:[NSNumber numberWithLongLong:_rowId]];
    }
    return [_entityManager execute:[NSString stringWithString:query] withArgs:fieldValues];
}

- (BOOL)isCreated
{
    return [_entityManager tableIsExist:[self tableName]];
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
            NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
            [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss"];
            NSDate *aFieldValue = [dateFormatter dateFromString:fieldValue];
            [dateFormatter release];
            return aFieldValue;
        }
    }
    return [NSNull null];
}

- (NSString *)buildQueryWithType:(NSString *)type
{
    NSMutableString *query = [NSMutableString string];
    if ([@"create" isEqualToString:type]) {
        [query appendString:[NSString stringWithFormat:@"CREATE TABLE IF NOT EXISTS %@ ( ", [self tableName]]];
    }else if ([@"save" isEqualToString:type]) {
        [query appendString:[NSString stringWithFormat:@"INSERT INTO %@ ( ", [self tableName]]];
    }
    
    NSMutableArray *fieldNames = [NSMutableArray array];
    NSMutableArray *fieldValues = [NSMutableArray array];
    
    NSDictionary *properties = [self properties];
    NSArray *allKeys = [properties allKeys];
    for (int i=0; i<[allKeys count]; i++) {
        NSString *propType = [allKeys objectAtIndex:i];
        NSString *propName = [properties objectForKey:propType];
        
        NSString *fieldType =  [WPEntityManager prop2field:propType];
        NSString *fieldName = camel2underline(propName);
        NSString *fieldValue = [self performSelector:@selector(propName)];
        
        if ([@"create" isEqualToString:type]) {
            if (i == ([allKeys count] - 1)) {
                [query appendString:[NSString stringWithFormat:@" %@ %@ ", fieldName, fieldType]];
            }else{
                [query appendString:[NSString stringWithFormat:@" %@ %@ , ", fieldName, fieldType]];
            }
        }
    }
    
    if ([@"create" isEqualToString:type]) {
        if ([self primaryKey] != nil) {
            [query appendString:[NSString stringWithFormat:@" , PRIMARY KEY (%@) ", [self primaryKey]]];
        }
        [query appendString:@" );"];
    }
    
    return [NSString stringWithString:query];
}



//This code is based from http://code.google.com/p/sqlitepersistentobjects/
+ (NSDictionary *)loadProperties
{
    // Recurse up the classes, but stop at NSObject. Each class only reports its own properties, not those inherited from its superclass
    NSMutableDictionary *theProps=nil;
    
    if ([self superclass] != [NSObject class])
        theProps = (NSMutableDictionary *)[[self superclass] loadProperties];
    else
        theProps = [NSMutableDictionary dictionary];
    
    unsigned int outCount;
    
    objc_property_t *propList = class_copyPropertyList([self class], &outCount);
    
    int i;
    
    // Loop through properties and add declarations for the create
    for (i=0; i < outCount; i++) {
        objc_property_t * oneProp = propList + i;
        NSString *propName = [NSString stringWithUTF8String:property_getName(*oneProp)];
        NSString *attrs = [NSString stringWithUTF8String: property_getAttributes(*oneProp)];
        NSArray *attrParts = [attrs componentsSeparatedByString:@","];
        
        //ignore the internal properties...
        if ([propName hasPrefix:@"_"]) {
            continue;
        }
        
        if (attrParts != nil){
            if ([attrParts count] > 0){
                NSString *propType = [[attrParts objectAtIndex:0] substringFromIndex:1];
                //Ignore arrays.
                if ([propType hasPrefix:@"@"] ) {
                    NSString *className = [propType substringWithRange:NSMakeRange(2, [propType length]-3)];
                    if ([WPEntityManager typeIsAllow:className]) {
                        [theProps setObject:className forKey:propName];
                    }
                }else{
                    [theProps setObject:propType forKey:propName];
                }
            }
        }
    }
    
    free( propList );
    return theProps;
}


#pragma mark 
#pragma mark overite KVC
- (id)valueForUndefinedKey:(NSString *)key
{
    return [NSNull null];
}


@end
