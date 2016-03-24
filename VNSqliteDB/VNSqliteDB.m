//
//  VNSqliteDB.m
//
//  Created by netmaid on 2015. 12. 28..
//  Copyright © 2015 netmaid. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <sqlite3.h>
#import "VNSqliteDB.h"


@interface VNSqliteDB ()
{
	sqlite3*	db;
}
@end


@interface VNSqliteRecord ()
{
	VNSqliteDB*		vndb;
	sqlite3_stmt*	stmt;
}
- (nullable instancetype)initWithStmt:(sqlite3_stmt*)stmt db:(VNSqliteDB*)db;
@end


@interface VNSqliteStatement ()
{
	VNSqliteDB*		vndb;
	sqlite3_stmt*	stmt;
	NSString*		sql;
	BOOL			isReference;
	
	int					bindIndex;
	NSMutableArray*		bindMembers;
}
- (nullable instancetype)initWithStmt:(sqlite3_stmt*)stmt db:(VNSqliteDB*)db sql:(NSString*)sql;
@end


@implementation VNSqliteDB

- (instancetype)init
{
	if (self = [super init])
	{
		db = NULL;
	}
	return self;
}

- (void)dealloc
{
	[self close];
}

- (BOOL)open
{
	[self close];
	
	const char* cFilePath = [_filePath cStringUsingEncoding:NSASCIIStringEncoding];
	
	int r = sqlite3_open(cFilePath, &db);
	if (r != SQLITE_OK)
	{
		[self onError:r at:@"open" message:NULL];
		return NO;
	}
	return YES;
}

- (BOOL)openWithFilePath:(NSString*)filePath
{
	[self close];
	
	_filePath = filePath;
	return [self open];
}

- (BOOL)openInMemoryWithSharedCache:(BOOL)useSharedCache
{
	_useInMemory = YES;
	_useSharedCache = useSharedCache;
	
	if (useSharedCache)
	{
		_filePath = @"file::memory:";
	}
	else
	{
		_filePath = @"file::memory:?cache=shared";
	}
	return [self open];
}

- (void)close
{
	if (db)
	{
		int r = sqlite3_close(db);
		if (r == SQLITE_BUSY)
		{
			[self onError:r at:@"close" message:NULL];
		}
		db = NULL;
	}
}

- (BOOL)execute:(NSString*)sql
{
	char* errorMsg = (char*)"";
	BOOL ret = YES;

	const char* cSql = [sql cStringUsingEncoding:NSASCIIStringEncoding];

	int r = sqlite3_exec(db, cSql, NULL, NULL, &errorMsg);
	if (r != SQLITE_OK)
	{
		[self onError:r at:@"execute" message:errorMsg];
		ret = NO;
	}
	
	if (errorMsg)
		sqlite3_free(errorMsg);
	
	return ret;
}

- (VNSqliteRecord*)executeForRecord:(NSString*)sql
{
	sqlite3_stmt* stmt;
	const char* tail = NULL;
	
	const char* cSql = [sql cStringUsingEncoding:NSASCIIStringEncoding];

	int r = sqlite3_prepare(db, cSql, -1, &stmt, &tail);
	if (r != SQLITE_OK)
	{
		[self onError:r at:@"execute" message:NULL];
		return nil;
	}
	
	VNSqliteRecord* record = [[VNSqliteRecord alloc] initWithStmt:stmt db:self];
	if (record == nil)
	{
		sqlite3_finalize(stmt);
	}
	return record;
}

- (nullable VNSqliteStatement*)prepareForStatement:(nonnull NSString*)sql
{
	sqlite3_stmt* stmt;
	
	const char* cSql = [sql cStringUsingEncoding:NSASCIIStringEncoding];
	
	int r = sqlite3_prepare_v2(db, cSql, -1, &stmt, NULL);
	if (r != SQLITE_OK)
	{
		[self onError:r at:@"prepare" message:sqlite3_errmsg(db)];
		return nil;
	}
	
	VNSqliteStatement* statement = [[VNSqliteStatement alloc] initWithStmt:stmt db:self sql:sql];
	if (statement == nil)
	{
		sqlite3_finalize(stmt);
	}
	return statement;
}

- (void)onError:(int)error at:(NSString*)at message:(const char*)message
{
	if (_delegate && [_delegate respondsToSelector:@selector(didErrorOccured:error:)])
	{
		NSString* sMessage = (message ? [NSString stringWithUTF8String:message]: @"");
		NSError* sError = [[NSError alloc] initWithDomain:sMessage code:error userInfo:nil];
		[_delegate didErrorOccured:self error:sError];
	}
}

- (BOOL)transact
{
	return [self execute:@"BEGIN"];
}

- (BOOL)rollback
{
	return [self execute:@"ROLLBACK"];
}

- (BOOL)commit
{
	return [self execute:@"COMMIT"];
}

- (int64_t)getInsertId
{
	return sqlite3_last_insert_rowid(db);
}
@end


@implementation VNSqliteRecord

- (instancetype)initWithStmt:(sqlite3_stmt*)stmt_ db:(VNSqliteDB*)db_
{
	if (self = [self init])
	{
		vndb = db_;
		stmt = stmt_;
	}
	else
	{
		vndb = NULL;
		stmt = NULL;
	}
	return self;
}

- (void)dealloc
{
	[self free];
}

- (BOOL)isAlloc
{
	return stmt != NULL;
}

- (void)free
{
	if (stmt != NULL)
	{
		sqlite3_finalize(stmt);
		stmt = NULL;
	}
}

- (BOOL)next
{
	int r = sqlite3_step(stmt);
	if (r == SQLITE_ROW)
	{
		return YES;
	}
	else if (r == SQLITE_DONE)
	{
		return NO;
	}
	else
	{
		[vndb onError:r at:@"VNSqliteRecord.next" message:NULL];
		return NO;
	}
}

- (id)objectAtIndexedSubscript:(unsigned int)idx
{
	id object = nil;
	
	int type = sqlite3_column_type(stmt, idx);
	switch (type)
	{
		case SQLITE_INTEGER:
		{
			sqlite_int64 val = sqlite3_column_int64(stmt, idx);
			object = [[NSNumber alloc] initWithLongLong:val];
			break;
		}
			
		case SQLITE_FLOAT:
		{
			double val = sqlite3_column_double(stmt, idx);
			object = [[NSNumber alloc] initWithDouble:val];
			break;
		}
			
		case SQLITE_BLOB:
		{
			const void* blob = sqlite3_column_blob(stmt, idx);
			int bytes = sqlite3_column_bytes(stmt, idx);
			object = [NSData dataWithBytes:blob length:bytes];
			break;
		}
			
		case SQLITE_NULL:
			break;
		
		case SQLITE_TEXT:
		{
			const unsigned char* text = sqlite3_column_text(stmt, idx);
			object = [NSString stringWithUTF8String:(const char*)text];
			break;
		}
	}
	return object;
}
@end


@implementation VNSqliteStatement

- (nullable instancetype)initWithStmt:(sqlite3_stmt*)stmt_ db:(VNSqliteDB*)db_ sql:(NSString*)sql_
{
	if (self = [self init])
	{
		vndb = db_;
		stmt = stmt_;
		sql = sql_;
		isReference = NO;
		bindIndex = 0;
		bindMembers = [NSMutableArray new];
	}
	return self;
}

- (void)dealloc
{
	[self free];
}

- (BOOL)isAlloc
{
	return stmt != NULL;
}

- (void)free
{
	if (stmt != NULL)
	{
		if (!isReference)
			sqlite3_finalize(stmt);
		stmt = NULL;
	}
}

- (void)reset
{
	if (stmt == NULL)
		return;
	
	bindIndex = 0;
	[bindMembers removeAllObjects];
	
	int r = sqlite3_clear_bindings(stmt);
	if (r != SQLITE_OK)
	{
		[vndb onError:r at:@"VNSqliteStatement.reset" message:"error bindings"];
	}
	
	r = sqlite3_reset(stmt);
	if (r != SQLITE_OK)
	{
		[vndb onError:r at:@"VNSqliteStatement.reset" message:"error reset"];
	}
}

- (BOOL)execute
{
	int r = sqlite3_step(stmt);
	if (r != SQLITE_DONE && r != SQLITE_ROW)
	{
		[vndb onError:r at:@"VNSqliteStatement.execute" message:NULL];
		return NO;
	}
	return YES;
}

- (BOOL)executeAndReset
{
	if ([self execute])
	{
		[self reset];
		return YES;
	}
	return NO;
}

- (nullable VNSqliteRecord*)executeForRecord
{
	VNSqliteRecord* record = [[VNSqliteRecord alloc] initWithStmt:stmt db:vndb];
	if (record)
	{
		isReference = YES;
	}
	return record;
}

- (BOOL)bind:(nonnull id)val
{
	++bindIndex;
	
	if (val == nil)
	{
		sqlite3_bind_null(stmt, bindIndex);
	}
	else if ([val isKindOfClass:[NSNumber class]])
	{
		NSNumber* number = val;
		CFNumberType numberType = CFNumberGetType((CFNumberRef)number);
		switch (numberType)
		{
			case kCFNumberSInt8Type:
				sqlite3_bind_int(stmt, bindIndex, number.charValue);
				break;
				
			case kCFNumberSInt16Type:
				sqlite3_bind_int(stmt, bindIndex, number.shortValue);
				break;
				
			case kCFNumberSInt32Type:
				sqlite3_bind_int(stmt, bindIndex, number.intValue);
				break;
				
			case kCFNumberSInt64Type:
				sqlite3_bind_int64(stmt, bindIndex, number.longLongValue);
				break;
				
			case kCFNumberFloat32Type:
				sqlite3_bind_double(stmt, bindIndex, number.floatValue);
				break;
				
			case kCFNumberFloatType:
				sqlite3_bind_double(stmt, bindIndex, number.floatValue);
				break;
				
			case kCFNumberFloat64Type:
				sqlite3_bind_double(stmt, bindIndex, number.doubleValue);
				break;
				
			case kCFNumberDoubleType:
				sqlite3_bind_double(stmt, bindIndex, number.doubleValue);
				break;
			
			case kCFNumberCharType:
				sqlite3_bind_int(stmt, bindIndex, number.charValue);
				break;
				
			case kCFNumberShortType:
				sqlite3_bind_int(stmt, bindIndex, number.shortValue);
				break;
				
			case kCFNumberIntType:
				sqlite3_bind_int(stmt, bindIndex, number.intValue);
				break;
				
			case kCFNumberLongType:
				sqlite3_bind_int64(stmt, bindIndex, number.longValue);
				break;
				
			case kCFNumberLongLongType:
				sqlite3_bind_int64(stmt, bindIndex, number.longLongValue);
				break;
				
			case kCFNumberCFIndexType: // CFIndex type
				sqlite3_bind_int64(stmt, bindIndex, number.longLongValue);
				break;
				
			case kCFNumberNSIntegerType:
				sqlite3_bind_int64(stmt, bindIndex, number.integerValue);
				break;
				
			case kCFNumberCGFloatType:
				sqlite3_bind_double(stmt, bindIndex, number.floatValue);
				break;
		}
	}
	else if ([val isKindOfClass:[NSString class]])
	{
		[bindMembers addObject:val];
		
		NSString* text = (NSString*) val;
		const char* cText = [text cStringUsingEncoding:NSASCIIStringEncoding];
		
		sqlite3_bind_text(stmt, bindIndex, cText, (int)strlen(cText), NULL);
	}
	else if ([val isKindOfClass:[NSData class]])
	{
		[bindMembers addObject:val];
		
		NSData* data = (NSData*) val;
		const void* cData = [data bytes];
		int dataLen = (int)[data length];
		
		sqlite3_bind_blob(stmt, bindIndex, cData, dataLen, 0);
	}
	else if ([val isKindOfClass:[NSDictionary class]])
	{
		[bindMembers addObject:val];
		
		NSString* json = [self jsonStringFromDictionary:(NSDictionary*)val];
		const char* Cjson = [json cStringUsingEncoding:NSASCIIStringEncoding];
		
		sqlite3_bind_text(stmt, bindIndex, Cjson, (int)strlen(Cjson), 0);
	}
	else {
		NSString* message = [NSString stringWithFormat:@"not supported type %@", NSStringFromClass([val class])];
		const char* cMessage = [message cStringUsingEncoding:NSASCIIStringEncoding];
		[vndb onError:-1 at:@"VNSqliteStatement.bind" message:cMessage];
		return NO;
	}
	return YES;
}

- (NSString*)jsonStringFromDictionary:(NSDictionary*)dictionary {
	NSError *error;
	NSData *jsonData = [NSJSONSerialization dataWithJSONObject:self
													   options:0
														 error:&error];
	if (jsonData == nil) {
		NSLog(@"jsonStringFromDictionary: error: %@", error.localizedDescription);
		return @"{}";
	}
	else {
		return [[NSString alloc] initWithData:jsonData encoding:NSUTF8StringEncoding];
	}
}

@end
