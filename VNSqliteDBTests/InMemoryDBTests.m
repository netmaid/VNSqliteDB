//
//  InMemoryDBTests.m
//  VNSqliteDB
//
//  Created by ened on 2016. 3. 23..
//  Copyright © 2016년 netmaid. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "VNSqliteDB.h"

@interface InMemoryDBTests : XCTestCase<VNSqliteDBDelegate>
{
	VNSqliteDB*		db;
}
@end

@implementation InMemoryDBTests

- (void)setUp {
    [super setUp];
	
	// Create database object
	db = [VNSqliteDB new];
	db.delegate = self;
}

- (void)tearDown {
	// Release database object
	db = nil;
	
    [super tearDown];
}

- (void)testExample {
	const int PERSON_COUNT = 10;
	
	
	// Open in-memory database
	XCTAssert( [db openInMemoryWithSharedCache:NO] );
	
	// Create person table
	NSString* createSql = @"CREATE TABLE IF NOT EXISTS person(idx INTEGER PRIMARY KEY ASC, name TEXT, age INTEGER)";
	XCTAssert( [db execute:createSql] );
	
	
	// Insert person sample data
	for (int i = 0; i < PERSON_COUNT; i++) {
		NSString* name = [NSString stringWithFormat:@"Name%zd", i];
		int age = rand()%50+1;
		NSString* query = [NSString stringWithFormat:@"INSERT INTO person(name, age) VALUES ('%@', %zd)", name, age];
		XCTAssert( [db execute:query] );
	}
	
	
	// Count all persons
	NSString* countSql = @"SELECT count(idx) FROM person";
	VNSqliteRecord* record = [db executeForRecord:countSql];
	XCTAssertNotNil( record );
	
	if (record) {
		while ([record next]) {
			NSNumber* count = record[0];
			XCTAssert( count.intValue == PERSON_COUNT );
		}
	}
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

#pragma mark - VNSqliteDBDelegate

- (void)didErrorOccured:(nonnull VNSqliteDB*)db error:(nullable NSError*)error {
	NSLog(@"%@", [error description]);
}

@end
