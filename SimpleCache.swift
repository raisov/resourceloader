//
//  ResourceCache.swift
//  ResourceLoader
//
//  Created by bp on 2018-10-02.
//  Copyright © 2018 Vladimir Raisov. All rights reserved.
//

import Foundation

fileprivate struct CacheElement {
    let data: Data

    private var lifeTime: Double
    private var hitCount: Double

    var rate: Double {
        return hitCount / lifeTime
    }

    var size: Int {
        return data.count
    }

    mutating func tick() {
        lifeTime = lifeTime + 1.0
    }

    mutating func hit() {
        hitCount = hitCount + 1.0
    }

    init(data: Data, initialRate: Double) {
        self.data = data
        self.lifeTime = 1.0
        self.hitCount = initialRate // give him a chance
    }
}

class SimpleCache: DataCache {

    private let capacity: Int

    private var pool = [Int : CacheElement]()
    private var totalRequest = 1.0
    private var totalHits = 0.1

    required init(capacity: Int) {
        assert(capacity >= 0)
        self.capacity = capacity
    }

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
            let needed = data.count
            guard needed <= capacity else {return}
            let averageRate = totalHits / totalRequest
            var free = capacity - pool.reduce(0){$0 + $1.value.size}
            let candidatesToTrash = pool.map{($0.key,$0.value.rate)}.filter{$0.1 < averageRate}.sorted{$0.1 < $1.1}.map{$0.0}
            for index in candidatesToTrash {
                if let removed = pool.removeValue(forKey: index) {
                    free += removed.size
                }
                if free >= needed {break}
            }
            if free >= needed {
                pool[index] = CacheElement(data: data, initialRate: averageRate)
            }
        }
    }

    func cleanUp() {
        pool.removeAll()
    }
}
