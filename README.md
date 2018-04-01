# CompilerKit

The goal of this project is to create a library of data structures and algorithms that can be used to build a compiler in Swift.

## Features

Since this project is under active development, it's very likely that the following lists are incomplete.

### Data Structures

- Classes of unicode scalars (`ScalarClass`).
- Regular expression (`RegularExpression`).
- Nondeterministic finite automata (`NFA`).
- Deterministic finite automata (`DFA`).
- Grammar (`Grammar`).

### Functions/Algorithms

- Matching a unicode scalar against a `ScalarClass`.
- Derive an `NFA` from a `RegularExpression`.
- Derive a `DFA` from an `NFA`.
- Minimize a `DFA`.
- Match a string against an `NFA` or `DFA` (i.e., execute finite state machine).
- Create a matcher that takes pairs of `RegularExpression`s and tokens and returns the correct token for a string based on match.
- Eliminate left recursion from a grammar.
- Perform left refactoring to eliminate backtracking.
- Check if a grammar is backtracking-free.
- Generate a table-driven LL(1) parser from a backtracking-free grammar, which reports whether the input was accepted or rejected.

## Example

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

    let nfa = NFA(scanner: scanner, nonAcceptingValue: .unknown)
    let dfa = nfa.dfa
    let minimizedDfa = dfa.minimized
                

    minimizedDfa.match("134")      // .integer
    minimizedDfa.match("61.613")   // .decimal
    minimizedDfa.match("x1")       // .identifier
    minimizedDfa.match("1xy")      // .unknown
```

## See Also

### Resources guiding this project

1. [Engineering a Compiler](https://www.cs.rice.edu/~keith/Errata.html) 2nd ed by Keith Cooper and Linda Torczon.

2. [Algorithms](https://algs4.cs.princeton.edu/home/) 4th ed by Robert Sedgewick and Kevin Wayne.

3. [Modern Compiler Implementation in C](https://www.cs.princeton.edu/~appel/modern/c/) by Maia Ginsburg and Andrew W. Appel.

4. [Modern Compiler Implementation in ML](https://www.cs.princeton.edu/~appel/modern/ml/) by Andrew W. Appel.

### My other projects, leading up to this

1. [slox](https://github.com/hashemi/slox) - Hand written scanner, recursive descent parser, and a tree-walking interpreter in Swift. See for a demonstration of using Swift's algebraic data types (`enum`s and `struct`s) to represent and render code. Implements the [lox programming language](http://www.craftinginterpreters.com). Ported from Java.

2. [bslox](https://github.com/hashemi/bslox) - Very early work-in-progress of what will eventually be a bytecode compiler and virtual machine of lox. Will be porting this from C.

3. [FlyingMonkey](https://github.com/hashemi/FlyingMonkey) - Hand written scanner and Pratt parser of the [monkey programming language](https://interpreterbook.com). Ported from Go.

4. [Sift](https://github.com/hashemi/Sift) - Hand written scanner and parser of [subset of Scheme](https://en.wikibooks.org/wiki/Write_Yourself_a_Scheme_in_48_Hours). Ported from Haskell.

5. [sparrow](https://github.com/hashemi/sparrow/blob/master/sparrow/Lexer.swift) - Hand written scanner of the Swift scanner from the official Swift compiler. Ported from the C++ to Swift. See for an example of a complex scanner/lexer with support for rewinding to arbitrary points in the input.

## License
MIT