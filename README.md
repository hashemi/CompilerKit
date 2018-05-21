# CompilerKit

[![Build Status](https://travis-ci.org/hashemi/CompilerKit.svg?branch=master)](https://travis-ci.org/hashemi/CompilerKit)

The goal of this project is to create a library of data structures and algorithms that can be used to build a compiler in Swift.

## Features

Since this project is under active development, it's very likely that the following lists are incomplete.

### Data Structures

- Classes of unicode scalars (`ScalarClass`).
- Regular expression (`RegularExpression`).
- Nondeterministic finite automata (`NFA`).
- Deterministic finite automata (`DFA`).
- Tokenizer (`Tokenizer`).
- Grammar (`Grammar`).
- LL parser (`LLParser`).
- SLR parser (`LRParser`).
- LALR parser (`LALRParser`).

### Functions/Algorithms

- Matching a unicode scalar against a `ScalarClass`.
- Derive an `NFA` from a `RegularExpression`.
- Derive a `DFA` from an `NFA`.
- Minimize a `DFA`.
- Match a string against an `NFA` or `DFA` (i.e., execute finite state machine).
- Create a matcher that takes pairs of `RegularExpression`s and tokens and returns the correct token for a string based on match.
- Create a tokenizer from pairs of `RegularExpression`s and tokens as well as a `RegularExpression` representing trivia between tokens that then takes a string and breaks it into individual tokens, skipping the trivia in between them.
- Eliminate left recursion from a grammar.
- Perform left refactoring to eliminate backtracking.
- Check if a grammar is backtracking-free.
- Generate a table-driven LL(1) parser from a backtracking-free grammar, which reports whether an input was accepted or rejected.
- Generate an DFA-backed SLR parser from a grammar, which reports whether an input was accepted or rejected.
- Construct a DFA-backed LALR parser from a grammar using the DeRemer and Pennello algorithm, which reports whether an input was accepted or rejected.

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

See the test suite for more usage examples.

## See Also

### Resources Used

1. [Engineering a Compiler](https://www.cs.rice.edu/~keith/Errata.html) 2nd ed by Keith Cooper and Linda Torczon.

2. [Algorithms](https://algs4.cs.princeton.edu/home/) 4th ed by Robert Sedgewick and Kevin Wayne.

3. [Stanford's Compilers Course](https://lagunita.stanford.edu/courses/Engineering/Compilers/Fall2014/about) by Alex Aiken.

4. [Compilers: Principles, Techniques, and Tools](https://en.wikipedia.org/wiki/Compilers:_Principles,_Techniques,_and_Tools) by  Alfred V. Aho, Monica S. Lam, Ravi Sethi, and Jeffrey D. Ullman.

5. [Efficient Computation of LALR(1) Look-Ahead Sets](https://dl.acm.org/citation.cfm?id=357187) by Frank DeRemer and Thomas Pennello.

6. [Modern Compiler Implementation in C](https://www.cs.princeton.edu/~appel/modern/c/) by Maia Ginsburg and Andrew W. Appel.

### My other projects, leading up to this

1. [slox](https://github.com/hashemi/slox) - Hand written scanner, recursive descent parser, and a tree-walking interpreter in Swift. See for a demonstration of using Swift's algebraic data types (`enum`s and `struct`s) to represent and render code. Implements the [lox programming language](http://www.craftinginterpreters.com). Ported from Java.

2. [bslox](https://github.com/hashemi/bslox) - Very early work-in-progress of what will eventually be a bytecode compiler and virtual machine of lox. Will be porting this from C.

3. [FlyingMonkey](https://github.com/hashemi/FlyingMonkey) - Hand written scanner and Pratt parser of the [monkey programming language](https://interpreterbook.com). Ported from Go.

4. [Sift](https://github.com/hashemi/Sift) - Hand written scanner and parser of [subset of Scheme](https://en.wikibooks.org/wiki/Write_Yourself_a_Scheme_in_48_Hours). Ported from Haskell.

5. [sparrow](https://github.com/hashemi/sparrow/blob/master/sparrow/Lexer.swift) - Hand written scanner of the Swift scanner from the official Swift compiler. Ported from the C++ to Swift. See for an example of a complex scanner/lexer with support for rewinding to arbitrary points in the input.

## License
MIT