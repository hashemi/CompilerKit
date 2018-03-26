struct Bitset {
    let maxValue: Int
    var storage: [UInt64]
    var range = (min: 0, max: 0)
    private(set) var isEmpty = true
    
    init(maxValue: Int) {
        self.maxValue = maxValue
        storage = Array(repeating: UInt64(0), count: (maxValue >> 6) + 1)
    }
    
    mutating func insert(_ element: Int) {
        precondition(element <= maxValue, "Element \(element) out of bounds for bitset with maximum value \(maxValue).")
        
        if isEmpty {
            range = (element, element)
            isEmpty = true
        } else {
            range.min = Swift.min(range.min, element)
            range.max = Swift.max(range.max, element)
        }
        
        isEmpty = false
        let index = element >> 6
        storage[index] |= 1 << (UInt64(element & 63))
    }
    
    func contains(_ element: Int) -> Bool {
        precondition(element <= maxValue, "Element \(element) out of bounds for bitset with maximum value \(maxValue).")
        
        let index = element >> 6
        return storage[index] & (1 << (UInt64(element & 63))) != 0
    }
    
    mutating func formUnion(_ other: Bitset) {
        precondition(other.maxValue == self.maxValue, "Cannot form a union between bitsets of two difference sizes.")
        if other.isEmpty { return }
        isEmpty = false
        range.min = Swift.min(range.min, other.range.min)
        range.max = Swift.max(range.max, other.range.max)
        for i in 0..<storage.count {
            storage[i] |= other.storage[i]
        }
    }
}

extension Bitset: Equatable {
    static func == (lhs: Bitset, rhs: Bitset) -> Bool {
        guard lhs.range == rhs.range else { return false }
        guard lhs.maxValue == rhs.maxValue else { return false }
        return lhs.storage == rhs.storage
    }
}

extension Bitset: Hashable {
    var hashValue: Int {
        return isEmpty ? 0 : Int(storage[0])
    }
}

extension Bitset: Sequence {
    func makeIterator() -> Bitset.Iterator {
        return Iterator(self)
    }
    
    struct Iterator: IteratorProtocol {
        let bitset: Bitset
        var tryNext: Int
        
        init(_ bitset: Bitset) {
            self.bitset = bitset
            self.tryNext = bitset.range.min
        }
        
        mutating func next() -> Int? {
            while tryNext <= bitset.range.max {
                let current = tryNext
                tryNext += 1
                
                if bitset.contains(current) {
                    return current
                }
            }
            return nil
        }
    }
}
