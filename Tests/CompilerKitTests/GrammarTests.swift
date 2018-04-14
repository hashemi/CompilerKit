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
        
        _ = LLParser(g)
        
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
        
        for s in GrammarTests.valid {
            XCTAssert(parser.parse(s))
        }
        
        for s in GrammarTests.invalid {
            XCTAssertFalse(parser.parse(s))
        }
    }
    
    func testLRConstruction() {
        let g = GrammarTests.grammar
        _ = LRParser(g)
    }

    func testLRParserCorrectness() {
        let g = GrammarTests.grammar
        let parser = LRParser(g)

        for s in GrammarTests.valid {
            XCTAssert(parser.parse(s))
        }
        
        for s in GrammarTests.invalid {
            XCTAssertFalse(parser.parse(s))
        }
    }

    func testLALRParserCorrectness() {
        let g = GrammarTests.grammar
        let parser = LALRParser(g)
        
        for s in GrammarTests.valid {
            XCTAssert(parser.parse(s))
        }

        for s in GrammarTests.invalid {
            XCTAssertFalse(parser.parse(s))
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
        
        func constructTransition(_ s: Set<LALRParser<Token>.Item>, _ nt: Int) -> LALRParser<Token>.Transition {
            return LALRParser<Token>.Transition(state: s, nt: nt)
        }
        
        func constructTransitionSet(_ s: [(Set<LALRParser<Token>.Item>, Int)]) -> Set<LALRParser<Token>.Transition> {
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
        
        // Item sets in an ordered array in the same order as the Dragon book
        // See Fig 4.35 in Dragon book for list of items (I0 to I11)
        let I = [
            /* I0  */ [(1, 0, 0), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (3, 0, 0)],
            /* I1  */ [(0, 0, 1), (3, 0, 1)],
            /* I2  */ [(0, 1, 1), (1, 0, 1)],
            /* I3  */ [(1, 1, 1)],
            /* I4  */ [(1, 0, 0), (2, 0, 1), (0, 1, 0), (0, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0)],
            /* I5  */ [(2, 1, 1)],
            /* I6  */ [(1, 0, 0), (2, 0, 0), (1, 1, 0), (2, 1, 0), (0, 0, 2)],
            /* I7  */ [(1, 0, 2), (2, 0, 0), (2, 1, 0)],
            /* I8  */ [(0, 0, 1), (2, 0, 2)],
            /* I9  */ [(1, 0, 1), (0, 0, 3)],
            /* I10 */ [(1, 0, 3)],
            /* I11 */ [(2, 0, 3)],
        ].map(constructItemSet)
        
        // The LR(0) item sets or "canonical set of LR(0) items"
        let itemSets = parser.itemSets()
        let expectedItemSets = Set(I)
        XCTAssertEqual(itemSets, expectedItemSets)
        
        // goto from state I1 {[E' -> E.], [E -> E. + T]} by token '+'...
        let gotoSet = parser.goto(I[1], .t(.plus))
        
        // ...and expect to land in state I6
        XCTAssertEqual(gotoSet, I[6])
        
        let allTransitions = parser.allTransitions(itemSets)
        let expectedTransitions = constructTransitionSet([
            (I[0], 0), (I[0], 1), (I[0], 2),
            (I[4], 0), (I[4], 1), (I[4], 2),
            (I[6], 1), (I[6], 2),
            (I[7], 2),
        ])
        
        XCTAssertEqual(allTransitions, expectedTransitions)
        
        // In the conventions of the paper by DeRemer & Pennello (1982),
        // this is a transition (I4, E) - with state I4, nonterminal E.
        // This transition lands us in state I8 {[F -> ( E .)], [E -> E .+ T]}
        let t = constructTransition(I[4], 0)
        let drTerminals = parser.directRead(t)
        XCTAssertEqual(drTerminals, [.plus, .rb])
        
        let reads = Dictionary(uniqueKeysWithValues: allTransitions.map {
            ($0, parser.reads($0))
        })
        let directRead = Dictionary(uniqueKeysWithValues: allTransitions.map {
            ($0, parser.directRead($0))
        })
        let indirectReads = parser.digraph(allTransitions, reads, directRead)

        // Without nullable terms, the 'reads' relationship is identical to direct read
        // TODO: test this with a grammar that has nullable rules
        XCTAssertEqual(directRead, indirectReads)
        
        let expectedFollowSets: [LALRParser<Token>.Transition: Set<Token>] = [
            constructTransition(I[0], 0): [.plus],
            constructTransition(I[0], 1): [.mult, .plus],
            constructTransition(I[0], 2): [.mult, .plus],
            constructTransition(I[4], 0): [.plus, .rb],
            constructTransition(I[4], 1): [.mult, .plus, .rb],
            constructTransition(I[4], 2): [.mult, .plus, .rb],
            constructTransition(I[6], 1): [.mult, .plus, .rb],
            constructTransition(I[6], 2): [.mult, .plus, .rb],
            constructTransition(I[7], 2): [.mult, .plus, .rb],
        ]
        let includes = Dictionary(uniqueKeysWithValues: allTransitions.map {
            ($0, parser.includes($0, allTransitions))
        })
        let followSets = parser.digraph(allTransitions, includes, indirectReads)
        XCTAssertEqual(expectedFollowSets, followSets)
        
        // make a list of all possible reduction items: [A -> w.]
        var reductions: [(Set<LALRParser<Token>.Item>, LALRParser<Token>.Item)] = []
        let prods = parser.grammar.productions
        for term in 0..<prods.count {
            for production in 0..<prods[term].count {
                let r = LALRParser<Token>.Item(term: term, production: production, position: prods[term][production].count)
                for state in itemSets where state.contains(r) {
                    reductions.append((state, r))
                }
            }
        }
        
        let lookbacks = reductions.map { state, reduction in parser.lookback(state, reduction, allTransitions) }
        let expectedLookbacks: [Set<LALRParser<Token>.Transition>] = [
            constructTransitionSet([(I[4], 0), (I[0], 0)]),
            constructTransitionSet([(I[4], 0), (I[0], 0)]),
            constructTransitionSet([(I[6], 1), (I[4], 1), (I[0], 1)]),
            constructTransitionSet([(I[6], 1), (I[4], 1), (I[0], 1)]),
            constructTransitionSet([(I[6], 2), (I[0], 2), (I[7], 2), (I[4], 2)]),
            constructTransitionSet([(I[6], 2), (I[0], 2), (I[7], 2), (I[4], 2)]),
            [],
        ]
        
        XCTAssertEqual(lookbacks, expectedLookbacks)
        
        let lookaheads: [Set<Token>] = reductions.map { state, reduction in
            var la: Set<Token> = []
            for transition in parser.lookback(state, reduction, allTransitions) {
                la.formUnion(followSets[transition]!)
            }
            return la
        }
        let expectedLookaheads: [Set<Token>] = [
            [.plus, .rb],
            [.plus, .rb],
            [.mult, .plus, .rb],
            [.mult, .plus, .rb],
            [.mult, .plus, .rb],
            [.mult, .plus, .rb],
            []
        ]
        XCTAssertEqual(lookaheads, expectedLookaheads)
    }
}
