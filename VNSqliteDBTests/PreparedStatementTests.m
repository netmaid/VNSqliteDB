//
//  PreparedStatementTests.m
//  VNSqliteDB
//
//  Created by ened on 2016. 3. 24..
//  Copyright © 2016 netmaid. All rights reserved.
//

#import <XCTest/XCTest.h>
#import "VNSqliteDB.h"

@interface PreparedStatementTests : XCTestCase<VNSqliteDBDelegate>
{
	VNSqliteDB*		db;
}
@end

@implementation PreparedStatementTests

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

	
	// Insert person sample data using prepared statement
	NSString* insertStatement = @"INSERT INTO person(name, age) VALUES (?,?)";
	VNSqliteStatement* statement = [db prepareForStatement:insertStatement];
	if (statement) {
		for (int i = 0; i < PERSON_COUNT; i++) {
			NSString* name = [NSString stringWithFormat:@"Name%zd", i];
			int age = rand()%50+1;

			[statement bind:name];
			[statement bind:[NSNumber numberWithInt:age]];
			[statement executeAndReset];
		}
	}
	
	
	// Get all person's name
	NSString* countSql = @"SELECT name FROM person ORDER BY idx ASC";
	VNSqliteRecord* record = [db executeForRecord:countSql];
	XCTAssertNotNil( record );
	
	if (record) {
		int curIdx = 0;
		while ([record next]) {
			NSString* name = record[0];
			NSString* expectName = [NSString stringWithFormat:@"Name%zd", curIdx];
			XCTAssertEqual( name, expectName );
			curIdx++;
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
