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
        
        func constructItemSet(_ s: [(Int, Int, Int)]) -> Set<LALRParser<Token>.Item> {
            return Set(s.map(LALRParser<Token>.Item.init))
        }
        
        func constructItemSets(_ s: [[(Int, Int, Int)]]) -> Set<Set<LALRParser<Token>.Item>> {
            return Set(s.map(constructItemSet))
        }
        
        func constructTransition(_ s: ([(Int, Int, Int)], Int)) -> LALRParser<Token>.Transition {
            return LALRParser<Token>.Transition(state: constructItemSet(s.0), nt: s.1)
        }
        
        func constructTransitionSet(_ s: [([(Int, Int, Int)], Int)]) -> Set<LALRParser<Token>.Transition> {
            return Set(s.map(constructTransition))
        }
        
        // This is Grammar 4.19 from the Dragon book
        // 0,0    E -> E + T
        // 0,1    E -> T
        // 1,0    T -> T * F
        // 1,1    T -> F
        // 2,0    F -> (E)
        // 2,1    F -> id
        // 3,0    E' -> E
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
        
        // The LR(0) item sets or "canonical set of LR(0) items"
        // See Fig 4.35 in the Dragon book for a list of those states (I0 to I11)
        let itemSets = parser.itemSets()
        let expectedItemSets =
        constructItemSets([
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
            ])
        XCTAssertEqual(itemSets, expectedItemSets)
        
        // goto from state I1 by token '+'...
        let gotoSet = parser.goto(constructItemSet([
                (3, 0, 1), // [E' -> E.]
                (0, 0, 1) // [E -> E. + T]
            ]), .t(.plus))
        
        // ...and expect to land in state I6
        let expectedGotoSet = constructItemSet([
                (0, 0, 2), // E -> E + .T
                (1, 0, 0), // T -> .T * F
                (1, 1, 0), // T -> .F
                (2, 0, 0), // F -> .(E)
                (2, 1, 0), // F -> .id
            ])
        XCTAssertEqual(gotoSet, expectedGotoSet)
        
        let allTransitions = parser.allTransitions(itemSets)
        let expectedTransitions = constructTransitionSet([
            ([(1, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (0, 0, 2)], 2),
            ([(1, 0, 0), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (3, 0, 0)], 2),
            ([(1, 0, 2), (2, 0, 0), (2, 1, 0)], 2),
            ([(1, 0, 0), (2, 0, 1), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0)], 1),
            ([(1, 0, 0), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (3, 0, 0)], 1),
            ([(1, 0, 0), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (3, 0, 0)], 0),
            ([(1, 0, 0), (2, 0, 1), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0)], 0),
            ([(1, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (0, 0, 2)], 1),
            ([(1, 0, 0), (2, 0, 1), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0)], 2),
        ])
        
        XCTAssertEqual(allTransitions, expectedTransitions)
        
        // In the conventions of the paper by DeRemer & Pennello (1982),
        // this is a transition (I4, E) - with state I4, nonterminal E.
        // This transition lands us in state I8 {[F -> ( E .)], [E -> E .+ T]}
        let t = constructTransition(([(1, 0, 0), (2, 0, 1), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0)], 0))
        let drTerminals = parser.directRead(t)
        XCTAssertEqual(drTerminals, [.plus, .rb])
    }
}
