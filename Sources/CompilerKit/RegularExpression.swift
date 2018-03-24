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
    
    static let digit: RegularExpression = "0" | "1" | "2" | "3" | "4" | "5" | "6" | "7" | "8" | "9"
    
    static let lowercase: RegularExpression = "a" | "b" | "c" | "d" | "e" | "f" | "g" | "h"
        | "i" | "j" | "k" | "l" | "m" | "n" | "o" | "p" | "q" | "r" | "s" | "t" | "u" | "v"
        | "w" | "x" | "y" | "z"

    static let uppercase: RegularExpression = "A" | "B" | "C" | "D" | "E" | "F" | "G" | "H"
        | "I" | "J" | "K" | "L" | "M" | "N" | "O" | "P" | "Q" | "R" | "S" | "T" | "U" | "V"
        | "W" | "X" | "Y" | "Z"
    
    static let alpha: RegularExpression = .lowercase | .uppercase
    
    static let alphanum: RegularExpression = .alpha | .digit
}

// Derive an NFA from a regular expression (Thompson's Construction)
extension RegularExpression {
    var nfa: NFA<Bool> {
        return NFA(re: self, acceptingValue: true, nonAcceptingValue: false)
    }
}
