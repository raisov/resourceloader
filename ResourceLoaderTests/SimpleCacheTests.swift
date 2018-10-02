//
//  SimpleCacheTests.swift
//  ResourceLoaderTests
//
//  Created by bp on 2018-10-02.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import XCTest
@testable import ResourceLoader

class SimpleCacheTests: XCTestCase {

    override func setUp() {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func cacheTest() {
        let data = [Data(),
                    "1".data(using: .ascii)!,
                    "12".data(using: .ascii)!,
                    "123".data(using: .ascii)!,
                    "1234".data(using: .ascii)!,
                    "12345".data(using: .ascii)!
        ]
        let capacity = data.reduce(1) {$0 + $1.count}
        let bigData = Data(count: capacity + 1)

        let cache = SimpleCache(capacity: capacity)

        // Margin tests
        cache[0] = data[0]
        var valueFromCache = cache[0]
        XCTAssertNotNil(valueFromCache)
        if let valueFromCache = valueFromCache {
            XCTAssertEqual(valueFromCache, data[0])
        }

        cache[data.count] = bigData
        XCTAssertNil(cache[data.count])

        // Match test
        for (index, data) in data.enumerated() {
            cache[index] = data
            let valueFromCache = cache[index]
            XCTAssertNotNil(valueFromCache)
            if let valueFromCache = valueFromCache {
                XCTAssertEqual(valueFromCache, data)
            }
        }

        // Yet another margin test
        cache[data.count] = data[0]
        valueFromCache = cache[0]
        XCTAssertNotNil(valueFromCache)
        if let valueFromCache = valueFromCache {
            XCTAssertEqual(valueFromCache, data[0])
        }
        for (index, _) in data.enumerated() {
            XCTAssertNotNil(cache[index])
        }

        // Replace value test
        let newData5  = Data(data[5].reversed())
        cache[5] = newData5
        valueFromCache = cache[5]
        XCTAssertNotNil(valueFromCache)
        if let valueFromCache = valueFromCache {
            XCTAssertEqual(valueFromCache, newData5)
        }
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }

}
