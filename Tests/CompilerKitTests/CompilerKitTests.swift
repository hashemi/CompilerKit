import XCTest
@testable import CompilerKit

final class CompilerKitTests: XCTestCase {
    func testNFA() {
        // a*ab - should match ab, aab, aaab, etc
        let nfa = NFA<Bool, ScalarClass>(
            states: 4,
            transitions: [
                .single("a"): [(0, 0), (1, 2)],
                .single("b"): [(2, 3)]
            ],
            epsilonTransitions: [0: [1]],
            initial: 0,
            accepting: [3: true],
            nonAcceptingValue: false)
        XCTAssertTrue(nfa.match("aaab".unicodeScalars))
        XCTAssertFalse(nfa.match("aaa".unicodeScalars))
        XCTAssertTrue(nfa.match("ab".unicodeScalars))
        XCTAssertFalse(nfa.match("b".unicodeScalars))
        XCTAssertFalse(nfa.match("bbbbab".unicodeScalars))
    }
    
    
    func testRegularExpression() {
        // a*ab - should match ab, aab, aaab, etc
        let re: RegularExpression = "a"* + ("a" + "b")
        let derivedNfa = re.nfa
        XCTAssertTrue(derivedNfa.match("aaab".unicodeScalars))
        XCTAssertFalse(derivedNfa.match("aaa".unicodeScalars))
        XCTAssertTrue(derivedNfa.match("ab".unicodeScalars))
        XCTAssertFalse(derivedNfa.match("b".unicodeScalars))
        XCTAssertFalse(derivedNfa.match("bbbbab".unicodeScalars))
    }
    
    func testDFA() {
        // a(b|c)* - should match a, ab, ac, abc, abbbb, acccc, abbccbcbbc, etc
        let dfa = DFA<Bool, ScalarClass>(
            states: 2,
            transitions: [
                DFA.Transition(from: 0, matcher: .single("a")): 1,
                DFA.Transition(from: 1, matcher: .single("b")): 1,
                DFA.Transition(from: 1, matcher: .single("c")): 1
            ],
            initial: 0,
            accepting: [1: true],
            nonAcceptingValue: false
        )
        
        XCTAssertTrue(dfa.match("a".unicodeScalars))
        XCTAssertTrue(dfa.match("ab".unicodeScalars))
        XCTAssertTrue(dfa.match("ac".unicodeScalars))
        XCTAssertTrue(dfa.match("abc".unicodeScalars))
        XCTAssertTrue(dfa.match("acb".unicodeScalars))
        XCTAssertTrue(dfa.match("abbbb".unicodeScalars))
        XCTAssertTrue(dfa.match("acccc".unicodeScalars))
        XCTAssertTrue(dfa.match("abbccbbccbc".unicodeScalars))

        XCTAssertFalse(dfa.match("aa".unicodeScalars))
        XCTAssertFalse(dfa.match("aba".unicodeScalars))
        XCTAssertFalse(dfa.match("abac".unicodeScalars))
        XCTAssertFalse(dfa.match("abbccbbccbca".unicodeScalars))
    }

    func testRegularExpressionToDFAMatch() {
        // a(b|c)* - should match a, ab, ac, abc, abbbb, acccc, abbccbcbbc, etc
        let re: RegularExpression = "a" + ("b" | "c")*
        let dfa = re.nfa.dfa
        
        XCTAssertTrue(dfa.match("a".unicodeScalars))
        XCTAssertTrue(dfa.match("ab".unicodeScalars))
        XCTAssertTrue(dfa.match("ac".unicodeScalars))
        XCTAssertTrue(dfa.match("abc".unicodeScalars))
        XCTAssertTrue(dfa.match("acb".unicodeScalars))
        XCTAssertTrue(dfa.match("abbbb".unicodeScalars))
        XCTAssertTrue(dfa.match("acccc".unicodeScalars))
        XCTAssertTrue(dfa.match("abbccbbccbc".unicodeScalars))
        
        XCTAssertFalse(dfa.match("aa".unicodeScalars))
        XCTAssertFalse(dfa.match("aba".unicodeScalars))
        XCTAssertFalse(dfa.match("abac".unicodeScalars))
        XCTAssertFalse(dfa.match("abbccbbccbca".unicodeScalars))
        XCTAssertFalse(dfa.match("cbcab".unicodeScalars))
    }

    func testRegularExpressionToMinimizedDFAMatch() {
        // a(b|c)* - should match a, ab, ac, abc, abbbb, acccc, abbccbcbbc, etc
        let re: RegularExpression = "a" + ("b" | "c")*
        let dfa = re.nfa.dfa.minimized

        XCTAssertTrue(dfa.match("a".unicodeScalars))
        XCTAssertTrue(dfa.match("ab".unicodeScalars))
        XCTAssertTrue(dfa.match("ac".unicodeScalars))
        XCTAssertTrue(dfa.match("abc".unicodeScalars))
        XCTAssertTrue(dfa.match("acb".unicodeScalars))
        XCTAssertTrue(dfa.match("abbbb".unicodeScalars))
        XCTAssertTrue(dfa.match("acccc".unicodeScalars))
        XCTAssertTrue(dfa.match("abbccbbccbc".unicodeScalars))
        
        XCTAssertFalse(dfa.match("aa".unicodeScalars))
        XCTAssertFalse(dfa.match("aba".unicodeScalars))
        XCTAssertFalse(dfa.match("abac".unicodeScalars))
        XCTAssertFalse(dfa.match("abbccbbccbca".unicodeScalars))
        XCTAssertFalse(dfa.match("cbcab".unicodeScalars))
    }
    
    func testMultiAcceptingStatesDFA() {
        enum Token { case aa, ab, ac, unknown }
        
        let dfa = DFA<Token, ScalarClass>(
            states: 5,
            transitions: [
                DFA.Transition(from: 0, matcher: .single("a")): 1,
                DFA.Transition(from: 1, matcher: .single("a")): 2,
                DFA.Transition(from: 1, matcher: .single("b")): 3,
                DFA.Transition(from: 1, matcher: .single("c")): 4,
            ],
            initial: 0,
            accepting: [2: .aa, 3: .ab, 4: .ac],
            nonAcceptingValue: .unknown
        )
        
        XCTAssertEqual(dfa.match("aa".unicodeScalars), .aa)
        XCTAssertEqual(dfa.match("ab".unicodeScalars), .ab)
        XCTAssertEqual(dfa.match("ac".unicodeScalars), .ac)
        XCTAssertEqual(dfa.match("bb".unicodeScalars), .unknown)
    }
    
    func testScanner() {
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

        measure {
            let dfa = NFA<Token, ScalarClass>(scanner: scanner, nonAcceptingValue: .unknown)
                        .dfa.minimized

            XCTAssertEqual(dfa.match("134".unicodeScalars), .integer)
            XCTAssertEqual(dfa.match("61.613".unicodeScalars), .decimal)
            XCTAssertEqual(dfa.match("x1".unicodeScalars), .identifier)
            XCTAssertEqual(dfa.match("1xy".unicodeScalars), .unknown)
        }
    }
    
    func testGrammar() {
        enum Token: CustomStringConvertible {
            case plus, minus, multiply, divide
            case leftBracket, rightBracket
            case num, name
            case eof
            
            var description: String {
                func q(_ s: String) -> String { return "\"\(s)\"" }
                switch self {
                case .plus: return q("+")
                case .minus: return q("-")
                case .multiply: return q("*")
                case .divide: return q("/")
                case .leftBracket: return q("(")
                case .rightBracket: return q(")")
                case .name: return "name"
                case .num: return "num"
                case .eof: return "eof"
                }
            }
        }
        
        var g = Grammar<Token>(productions:
            [
                // (0) Goal   -> Expr
                [
                    [.nt(1), .t(.eof)],
                ],
                
                // (1) Expr   -> Expr + Term
                //             | Expr - Term
                //             | Term
                [
                    [.nt(1), .t(.plus), .nt(2)],
                    [.nt(1), .t(.minus), .nt(2)],
                    [.nt(2)],
                ],

                // (2) Term   -> Term x Factor
                //             | Term / Factor
                //             | Factor
                [
                    [.nt(2), .t(.multiply), .nt(3)],
                    [.nt(2), .t(.divide), .nt(3)],
                    [.nt(3)],
                ],

                // (3) Factor -> ( Expr )
                //             | num
                //             | name
                [
                    [.t(.leftBracket), .nt(1), .t(.rightBracket)],
                    [.t(.num)],
                    [.t(.name)],
                ],
            ]
        )
        
        g.eliminateLeftRecursion()
        XCTAssertEqual(g.productions.count, 6)
        
        let (firstSets, canBeEmpty) = g.first
        XCTAssertEqual(firstSets,
            [
                [.num:      [0], .leftBracket: [0], .name: [0]],
                [.num:      [0], .leftBracket: [0], .name: [0]],
                [.num:      [0], .leftBracket: [0], .name: [0]],
                [.num:      [1], .leftBracket: [0], .name: [2]],
                [.plus:     [1], .minus:       [2]],
                [.multiply: [1], .divide:      [2]],
            ])
        XCTAssertEqual(canBeEmpty, [[], [], [], [], [0], [0]])
        XCTAssertEqual(g.follow, [
                Set<Token>([]),
                Set<Token>([.eof, .rightBracket]),
                Set<Token>([.eof, .rightBracket, .plus, .minus]),
                Set<Token>([.eof, .rightBracket, .plus, .minus, .multiply, .divide]),
                Set<Token>([.eof, .rightBracket]),
                Set<Token>([.eof, .rightBracket, .plus, .minus]),
            ])
        XCTAssert(g.isBacktrackFree)
        XCTAssertEqual(g.parsingTable,
            [
                [.num: 0, .leftBracket: 0, .name: 0],
                [.num: 0, .leftBracket: 0, .name: 0],
                [.num: 0, .leftBracket: 0, .name: 0],
                [.num: 1, .leftBracket: 0, .name: 2],
                [.rightBracket: 0, .plus: 1, .minus: 2, .eof: 0],
                [.rightBracket: 0, .minus: 0, .multiply: 1, .divide: 2, .plus: 0, .eof: 0]
            ])
        
        XCTAssert(g.parse(term: 0, [.num, .eof]))
        XCTAssert(g.parse(term: 0, [.num, .plus, .name, .eof]))
        XCTAssert(g.parse(term: 0, [.leftBracket, .num, .plus, .num, .rightBracket, .eof]))
        
        // missing eof
        XCTAssertFalse(g.parse(term: 0, [.num]))
        
        // unbalanced brackets
        XCTAssertFalse(g.parse(term: 0, [.leftBracket, .leftBracket, .rightBracket, .num, .rightBracket, .eof]))
        
        // name followed by num
        XCTAssertFalse(g.parse(term: 0, [.name, .num, .eof]))
    }
    
    func testBacktrackingGrammar() {
        enum Token: CustomStringConvertible {
            case plus, minus, multiply, divide
            case leftBracket, rightBracket
            case comma
            case num, name
            case eof
            
            var description: String {
                func q(_ s: String) -> String { return "\"\(s)\"" }
                switch self {
                case .plus: return q("+")
                case .minus: return q("-")
                case .multiply: return q("*")
                case .divide: return q("/")
                case .leftBracket: return q("(")
                case .rightBracket: return q(")")
                case .comma: return q(",")
                case .name: return "name"
                case .num: return "num"
                case .eof: return "eof"
                }
            }
        }
        
        var g = Grammar<Token>(productions:
            [
                // (0) Goal   -> Expr
                [
                    [.nt(1)],
                ],
            
                // (1) Expr   -> Expr + Term
                //             | Expr - Term
                //             | Term
                [
                    [.nt(1), .t(.plus), .nt(2)],
                    [.nt(1), .t(.minus), .nt(2)],
                    [.nt(2)],
                ],
            
                // (2) Term   -> Term x Factor
                //             | Term / Factor
                //             | Factor
                [
                    [.nt(2), .t(.multiply), .nt(3)],
                    [.nt(2), .t(.divide), .nt(3)],
                    [.nt(3)],
                ],
            
                // (3) Factor -> ( Expr )
                //             | num
                //             | name
                [
                    [.t(.leftBracket), .nt(1), .t(.rightBracket)],
                    [.t(.num)],
                    [.t(.name)],
                    [.t(.name), .t(.leftBracket), .nt(4), .t(.rightBracket)],
                ],
                // (4) ArgList -> Expr
                [
                    [.nt(1)]
                ],
            ]
        )
        
        g.eliminateLeftRecursion()
        XCTAssertEqual(g.productions.count, 7)
        
        // there are two productions of Factor starting with .name
        XCTAssertEqual(g.first.0[3][.name]?.count, 2)
        
        // ... which means that the grammar is NOT backtrack free
        XCTAssert(!g.isBacktrackFree)
        
        g.leftRefactor()
        XCTAssert(g.isBacktrackFree)
    }
    
    func testLRParser() {
        enum Token: CustomStringConvertible {
            func q(_ s: String) -> String { return "'\(s)'" }
            case plus, multiply
            case leftBracket, rightBracket
            case int
            case eof
            
            var description: String {
                switch self {
                case .plus: return q("+")
                case .multiply: return q("*")
                case .leftBracket: return q("(")
                case .rightBracket: return q(")")
                case .int: return "int"
                case .eof: return "eof"
                }
            }
        }
        
        let g = Grammar<Token>(productions:
            [
                // (0) E -> T | T + E
                [[.nt(1)], [.nt(1), .t(.plus), .nt(0)]],
                
                // (1) T -> int | int * T | ( E )
                [[.t(.int)], [.t(.int), .t(.multiply), .nt(1)], [.t(.leftBracket), .nt(0), .t(.rightBracket)]],
            ]
        )
        
        let parser = LRParser(g, 0)
        XCTAssert(parser.parse([.int, .multiply, .int, .plus, .int]))
    }
    
    func testLRParser2() {
        enum Token: CustomStringConvertible {
            case plus, minus, multiply, divide
            case leftBracket, rightBracket
            case num, name
            case eof
            
            var description: String {
                func q(_ s: String) -> String { return "\"\(s)\"" }
                switch self {
                case .plus: return q("+")
                case .minus: return q("-")
                case .multiply: return q("*")
                case .divide: return q("/")
                case .leftBracket: return q("(")
                case .rightBracket: return q(")")
                case .name: return "name"
                case .num: return "num"
                case .eof: return "eof"
                }
            }
        }
        
        let g = Grammar<Token>(productions:
            [
                // (0) Goal   -> Expr
                [
                    [.nt(1), .t(.eof)],
                    ],
                
                // (1) Expr   -> Expr + Term
                //             | Expr - Term
                //             | Term
                [
                    [.nt(1), .t(.plus), .nt(2)],
                    [.nt(1), .t(.minus), .nt(2)],
                    [.nt(2)],
                    ],
                
                // (2) Term   -> Term x Factor
                //             | Term / Factor
                //             | Factor
                [
                    [.nt(2), .t(.multiply), .nt(3)],
                    [.nt(2), .t(.divide), .nt(3)],
                    [.nt(3)],
                    ],
                
                // (3) Factor -> ( Expr )
                //             | num
                //             | name
                [
                    [.t(.leftBracket), .nt(1), .t(.rightBracket)],
                    [.t(.num)],
                    [.t(.name)],
                    ],
                ]
        )
        
        let parser = LRParser(g, 0)
        
        XCTAssert(parser.parse([.num, .eof]))
        XCTAssert(parser.parse([.num, .plus, .name, .eof]))
        XCTAssert(parser.parse([.leftBracket, .num, .plus, .num, .rightBracket, .eof]))
        
        // missing eof
        XCTAssertFalse(parser.parse([.num]))
        
        // unbalanced brackets
        XCTAssertFalse(parser.parse([.leftBracket, .leftBracket, .rightBracket, .num, .rightBracket, .eof]))
        
        // name followed by num
        XCTAssertFalse(parser.parse([.name, .num, .eof]))
    }
    
    
    static var allTests = [
        ("testNFA", testNFA),
        ("testRegularExpression", testRegularExpression),
        ("testDFA", testDFA),
        ("testRegularExpressionToDFAMatch", testRegularExpressionToDFAMatch),
        ("testRegularExpressionToMinimizedDFAMatch", testRegularExpressionToMinimizedDFAMatch),
    ]
}
