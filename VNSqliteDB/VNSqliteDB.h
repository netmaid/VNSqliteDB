//
//  VNSqliteDB.h
//
//  Created by netmaid on 2015. 12. 28..
//  Copyright © 2015 netmaid. All rights reserved.
//


@class VNSqliteDB;
@class VNSqliteRecord;
@class VNSqliteStatement;


@protocol VNSqliteDBDelegate <NSObject>
- (void)didErrorOccured:(nonnull VNSqliteDB*)db error:(nullable NSError*)error;
@end


@interface VNSqliteDB: NSObject

@property (nonatomic,weak) id<VNSqliteDBDelegate>	delegate;
@property (nonatomic,strong,nullable) NSString*		filePath;
@property (nonatomic,assign) BOOL					useInMemory;
@property (nonatomic,assign) BOOL					useSharedCache;

- (BOOL)open;
- (BOOL)openWithFilePath:(nonnull NSString*)filePath;
- (void)close;

- (BOOL)execute:(nonnull NSString*)sql;
- (nullable VNSqliteRecord*)executeForRecord:(nonnull NSString*)sql;
- (nullable VNSqliteStatement*)prepareForStatement:(nonnull NSString*)sql;

- (BOOL)transact;
- (BOOL)rollback;
- (BOOL)commit;

- (int64_t)getInsertId;
@end


@interface VNSqliteRecord: NSObject

- (BOOL)next;

- (nullable id)objectAtIndexedSubscript:(unsigned int)idx;
@end


@interface VNSqliteStatement: NSObject

- (void)reset;
- (BOOL)execute;
- (nullable VNSqliteRecord*)executeForRecord;

- (BOOL)bind:(nonnull id)val;
@end
