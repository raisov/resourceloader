//
//  ResourceCache.swift
//  ResourceLoader
//
//  Created by bp on 2018-10-02.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import Foundation

/// Data stored in cache.
fileprivate struct CacheElement {
    let data: Data

    /// How many times cache was accessed after this data has been saved.
    private var lifeTime: Double
    /// How many times these data queried.
    private var hitCount: Double

    /// Frequency of this data  using.
    var frequency: Double {
        return hitCount / lifeTime
    }

    /// Size of data.
    var size: Int {
        return data.count
    }

    /// Called each time when cache queries.
    mutating func tick() {
        lifeTime = lifeTime + 1.0
    }

    /// Called each time these data received from cache.
    mutating func hit() {
        hitCount = hitCount + 1.0
    }

    /// Creates cache element.
    /// - Parameters:
    ///     - data: cached data.
    ///     - initialFrequency: Assumed using frequency.
    init(data: Data, initialFrequency: Double) {
        self.data = data
        self.lifeTime = 1.0
        self.hitCount = initialFrequency
    }
}

/// Simple inmemory cache.
class SimpleCache: DataCache {

    /// Maximum amount of data in cache.
    private let capacity: Int

    private var pool = [Int : CacheElement]()
    private var totalRequest = 1.0
    private var totalHits = 0.1

    required init(capacity: Int) {
        assert(capacity >= 0)
        self.capacity = capacity
    }

    /// Cached data put/get.
    /// - Parameter index: unique data identifier.
    subscript(index: Int) -> Data? {

        get {
            pool.forEach {
                var value = $0.value
                value.tick()
                pool[$0.key] = value
            }
            totalRequest = totalRequest + 1.0
            guard var result = pool[index] else {return nil}
            totalHits = totalHits + 1.0
            result.hit()
            pool[index] = result
            return result.data
        }

        set {
            guard let data = newValue else {return}
            pool.removeValue(forKey: index)
            let needed = data.count
            guard needed <= capacity else {return}
            let averageFrequence = totalHits / totalRequest
            var free = capacity - pool.reduce(0){$0 + $1.value.size}
            let candidatesToTrash = pool.map{($0.key,$0.value.frequency, $0.value.size)}.filter{
                   $0.1 <= averageFrequence //
                }
                // [(index, frequency, size)]
                // where frequency <= averageFrequency

            for (index, _, _) in (candidatesToTrash.sorted{($0.1 == $1.1) ? ($0.2 > $1.2) : ($0.1 < $0.1)}) {
                                  // sorted by increasing frequency order.
                                  // For equal frequencies, the first is a larger element.
                if let removed = pool.removeValue(forKey: index) {
                    free += removed.size
                }
                if free >= needed {break}
            }
            if free >= needed {
                pool[index] = CacheElement(data: data, initialFrequency: averageFrequence)
            }
        }
    }

    /// Flush all cached data.
    func cleanUp() {
        pool.removeAll()
    }
}
