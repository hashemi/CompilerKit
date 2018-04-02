indirect enum RegularExpression {
    case scalarClass(ScalarClass)
    case alternation(RegularExpression, RegularExpression)
    case concatenation(RegularExpression, RegularExpression)
    case closure(RegularExpression)
}

// A more convenient way for building a regular expression in Swift code
postfix operator *

extension RegularExpression: ExpressibleByUnicodeScalarLiteral {
    init(unicodeScalarLiteral scalar: UnicodeScalar) {
        self = .scalarClass(.single(scalar))
    }
    
    static func +(lhs: RegularExpression, rhs: RegularExpression) -> RegularExpression {
        return .concatenation(lhs, rhs)
    }
    
    static func |(lhs: RegularExpression, rhs: RegularExpression) -> RegularExpression {
        return .alternation(lhs, rhs)
    }
    
    static postfix func *(re: RegularExpression) -> RegularExpression {
        return .closure(re)
    }
    
    static let digit: RegularExpression = .scalarClass(.range("0", "9"))
    
    static let lowercase: RegularExpression = .scalarClass(.range("a", "z"))

    static let uppercase: RegularExpression = .scalarClass(.range("A", "Z"))
    
    static let alpha: RegularExpression = .lowercase | .uppercase
    
    static let alphanum: RegularExpression = .alpha | .digit
}

// Derive an NFA from a regular expression (Thompson's Construction)
extension RegularExpression {
    var nfa: NFA<Bool, ScalarClass> {
        return NFA(re: self, acceptingValue: true, nonAcceptingValue: false)
    }
}
