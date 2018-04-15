extension Dictionary {
    init(_ keys: Set<Key>, _ value: (Key) -> Value) {
        self.init(uniqueKeysWithValues: keys.map { ($0, value($0)) })
    }
}
