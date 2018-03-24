indirect enum RegularExpression {
    case scalar(UnicodeScalar)
    case alternation(RegularExpression, RegularExpression)
    case concatenation(RegularExpression, RegularExpression)
    case closure(RegularExpression)
}

// A more convenient way for building a regular expression in Swift code
postfix operator *

extension RegularExpression: ExpressibleByUnicodeScalarLiteral {
    init(unicodeScalarLiteral scalar: UnicodeScalar) {
        self = .scalar(scalar)
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
}

// Derive an NFA from a regular expression (Thompson's Construction)
extension RegularExpression {
    var nfa: NFA<Bool> {
        return NFA(re: self, acceptingValue: true, nonAcceptingValue: false)
    }
}
