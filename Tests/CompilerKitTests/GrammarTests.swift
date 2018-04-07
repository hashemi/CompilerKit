import XCTest
@testable import CompilerKit

final class GrammarTests: XCTestCase {
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
            ],
            start: 0
        )
        
        g.eliminateLeftRecursion()
        XCTAssertEqual(g.productions.count, 6)
        
        let nullable = g.nullable()
        XCTAssertEqual(nullable, [[], [], [], [], [0], [0]])
        
        let first = g.first(nullable: nullable)
        XCTAssertEqual(first,
            [
                [.num:      [0], .leftBracket: [0], .name: [0]],
                [.num:      [0], .leftBracket: [0], .name: [0]],
                [.num:      [0], .leftBracket: [0], .name: [0]],
                [.num:      [1], .leftBracket: [0], .name: [2]],
                [.plus:     [1], .minus:       [2]],
                [.multiply: [1], .divide:      [2]],
            ])
        
        let follow = g.follow(nullable: nullable, first: first)
        XCTAssertEqual(follow, [
                Set<Token>([]),
                Set<Token>([.eof, .rightBracket]),
                Set<Token>([.eof, .rightBracket, .plus, .minus]),
                Set<Token>([.eof, .rightBracket, .plus, .minus, .multiply, .divide]),
                Set<Token>([.eof, .rightBracket]),
                Set<Token>([.eof, .rightBracket, .plus, .minus]),
            ])
        
        XCTAssert(g.isBacktrackFree(nullable: nullable, first: first, follow: follow))
        
        let parser = LLParser(g)
        XCTAssertEqual(parser.table,
            [
                [.num: 0, .leftBracket: 0, .name: 0],
                [.num: 0, .leftBracket: 0, .name: 0],
                [.num: 0, .leftBracket: 0, .name: 0],
                [.num: 1, .leftBracket: 0, .name: 2],
                [.rightBracket: 0, .plus: 1, .minus: 2, .eof: 0],
                [.rightBracket: 0, .minus: 0, .multiply: 1, .divide: 2, .plus: 0, .eof: 0]
            ])
        
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
            ],
            start: 0
        )
        
        g.eliminateLeftRecursion()
        XCTAssertEqual(g.productions.count, 7)
        
        // there are two productions of Factor starting with .name
        let nullable = g.nullable()
        let first = g.first(nullable: nullable)
        let follow = g.follow(nullable: nullable, first: first)

        XCTAssertEqual(first[3][.name]?.count, 2)
        
        // ... which means that the grammar is NOT backtrack free
        XCTAssert(!g.isBacktrackFree(nullable: nullable, first: first, follow: follow))
        
        g.leftRefactor()
        let newNullable = g.nullable()
        let newFirst = g.first(nullable: newNullable)
        let newFollow = g.follow(nullable: newNullable, first: newFirst)
        XCTAssert(g.isBacktrackFree(nullable: newNullable, first: newFirst, follow: newFollow))
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
            ],
            start: 0
        )
        
        let parser = LRParser(g)
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
                ],
                start: 0
        )
        
        let parser = LRParser(g)
        
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
}
