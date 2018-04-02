enum ScalarClass: Hashable, Matcher {
    typealias Element = UnicodeScalar
    
    case single(UnicodeScalar)
    case range(UnicodeScalar, UnicodeScalar)
    
    static func ~=(pattern: ScalarClass, value: UnicodeScalar) -> Bool {
        switch pattern {
        case let .single(scalar):
            return value == scalar
            
        case let .range(from, to):
            return from <= value && value <= to
        }
    }
}

