# CompilerKit

The goal of this project is to create a library of data structures and algorithms that can be used to build a compiler in Swift.

It currently supports taking a list of `RegularExpression` to a value (e.g., token type) pairs and generating an `NFA`, deriving a `DFA` from that, minimizing the `DFA`, and matching against a string:

```swift
    enum Token {
        case integer
        case decimal
        case identifier
        case unknown
    }
    
    let scanner: [(RegularExpression, Token)] = [
        (.digit + .digit*, .integer),
        (.digit + .digit* + "." + .digit + .digit*, .decimal),
        (.alpha + .alphanum*, .identifier),
    ]

    let dfa = NFA<Token>(scanner: scanner, nonAcceptingValue: .unknown)
                .dfa.minimized

    dfa.match("134")      // .integer
    dfa.match("61.613")   // .decimal
    dfa.match("x1")       // .identifier
    dfa.match("1xy")      // .unknown
```
