import XCTest
@testable import CompilerKit

final class GrammarTests: XCTestCase {
    enum Token: CustomStringConvertible {
        case plus, minus, multiply, divide
        case leftBracket, rightBracket
        case num, name
        case eof
        
        var description: String {
            func q(_ s: String) -> String { return "'\(s)'" }
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

    static let grammar = Grammar<Token>(
        productions: [
            // (0) Goal   -> Expr
            [[.nt(1), .t(.eof)]],
            
            // (1) Expr   -> Expr + Term
            //             | Expr - Term
            //             | Term
            [[.nt(1), .t(.plus), .nt(2)],
             [.nt(1), .t(.minus), .nt(2)],
             [.nt(2)]],
            
            // (2) Term   -> Term x Factor
            //             | Term / Factor
            //             | Factor
            [[.nt(2), .t(.multiply), .nt(3)],
             [.nt(2), .t(.divide), .nt(3)],
             [.nt(3)]],
            
            // (3) Factor -> ( Expr )
            //             | num
            //             | name
            [[.t(.leftBracket), .nt(1), .t(.rightBracket)],
             [.t(.num)],
             [.t(.name)]]
        ],
        start: 0
    )
    
    static let valid: [[Token]] = [
        [.num, .eof],
        [.num, .plus, .name, .eof],
        [.leftBracket, .num, .plus, .num, .rightBracket, .eof],
    ]
    
    static let invalid: [[Token]] = [
        // missing eof
        [.num],
        // unbalanced brackets
        [.leftBracket, .leftBracket, .rightBracket, .num, .rightBracket, .eof],
        // name followed by num
        [.name, .num, .eof],
    ]
    
    func testGrammar() {
        var g = GrammarTests.grammar
        
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
    }
    
    func testLLParserConstruction() {
        let g = GrammarTests.grammar
        
        measure {
            _ = LLParser(g)
        }
        
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
    }
    
    func testLLParserCorrectness() {
        let g = GrammarTests.grammar
        let parser = LLParser(g)
        
        measure {
            for s in GrammarTests.valid {
                XCTAssert(parser.parse(s))
            }
            
            for s in GrammarTests.invalid {
                XCTAssertFalse(parser.parse(s))
            }
        }
    }
    
    func testLRConstruction() {
        let g = GrammarTests.grammar
        measure {
            _ = LRParser(g)
        }
    }

    func testLRParserCorrectness() {
        let g = GrammarTests.grammar
        let parser = LRParser(g)

        measure {
            for s in GrammarTests.valid {
                XCTAssert(parser.parse(s))
            }
            
            for s in GrammarTests.invalid {
                XCTAssertFalse(parser.parse(s))
            }
        }
    }

    func testBacktrackingGrammar() {
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
    
    func testLALR() {
        enum Token: String, Hashable {
            case lb, rb, id, plus, mult
        }
        typealias Item = LALRParser<Token>.Item
        
        let g = Grammar<Token>(productions: [
                // E -> E + T | T
                [[.nt(0), .t(.plus), .nt(1)], [.nt(1)]],
                // T -> T * F | F
                [[.nt(1), .t(.mult), .nt(2)], [.nt(2)]],
                // F -> (E) | id
                [[.t(.lb), .nt(0), .t(.rb)], [.t(.id)]],
            ],
                        start: 0)
        
        let parser = LALRParser(g)
        
        let expectedItemSets: Set<Set<LALRParser<Token>.Item>> =
        Set([
            [(1, 0, 2), (2, 0, 0), (2, 1, 0)],
            [(1, 0, 0), (2, 0, 1), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0)],
            [(0, 0, 1), (2, 0, 2)],
            [(1, 0, 3)],
            [(1, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (0, 0, 2)],
            [(2, 0, 3)],
            [(1, 0, 1), (0, 0, 3)],
            [(1, 0, 0), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (3, 0, 0)],
            [(0, 0, 1), (3, 0, 1)],
            [(1, 1, 1)],
            [(2, 1, 1)],
            [(0, 1, 1), (1, 0, 1)]
            ].map { Set($0.map(Item.init)) })
        XCTAssertEqual(parser.itemSets(), expectedItemSets)
        
        let gotoSet = parser.goto([
                Item(term: 3, production: 0, position: 1), // [E' -> E.]
                Item(term: 0, production: 0, position: 1) // [E -> E. + T]
            ], .t(.plus))
        
        let expectedGotoSet: Set<Item> = Set([
            (0, 0, 2), // E -> E + .T
            (1, 0, 0), // T -> .T * F
            (1, 1, 0), // T -> .F
            (2, 0, 0), // F -> .(E)
            (2, 1, 0), // F -> .id
            ].map(Item.init))
        
        XCTAssertEqual(gotoSet, expectedGotoSet)
    }
}
