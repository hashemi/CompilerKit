import XCTest
@testable import CompilerKit

final class CompilerKitTests: XCTestCase {
    func testNFA() {
        // a*ab - should match ab, aab, aaab, etc
        let nfa = NFA(
            vertices: 4,
            edges: [
                .single("a"): [(0, 0), (1, 2)],
                .single("b"): [(2, 3)]
            ],
            epsilonTransitions: [0: [1]],
            initial: 0,
            accepting: [3: true],
            nonAcceptingValue: false)
        XCTAssertTrue(nfa.match("aaab"))
        XCTAssertFalse(nfa.match("aaa"))
        XCTAssertTrue(nfa.match("ab"))
        XCTAssertFalse(nfa.match("b"))
        XCTAssertFalse(nfa.match("bbbbab"))
    }
    
    
    func testRegularExpression() {
        // a*ab - should match ab, aab, aaab, etc
        let re: RegularExpression = "a"* + ("a" + "b")
        let derivedNfa = re.nfa
        XCTAssertTrue(derivedNfa.match("aaab"))
        XCTAssertFalse(derivedNfa.match("aaa"))
        XCTAssertTrue(derivedNfa.match("ab"))
        XCTAssertFalse(derivedNfa.match("b"))
        XCTAssertFalse(derivedNfa.match("bbbbab"))
    }
    
    func testDFA() {
        // a(b|c)* - should match a, ab, ac, abc, abbbb, acccc, abbccbcbbc, etc
        let dfa = DFA(
            vertices: 2,
            edges: [
                DFA.Edge(from: 0, scalar: .single("a")): 1,
                DFA.Edge(from: 1, scalar: .single("b")): 1,
                DFA.Edge(from: 1, scalar: .single("c")): 1
            ],
            initial: 0,
            accepting: [1: true],
            nonAcceptingValue: false
        )
        
        XCTAssertTrue(dfa.match("a"))
        XCTAssertTrue(dfa.match("ab"))
        XCTAssertTrue(dfa.match("ac"))
        XCTAssertTrue(dfa.match("abc"))
        XCTAssertTrue(dfa.match("acb"))
        XCTAssertTrue(dfa.match("abbbb"))
        XCTAssertTrue(dfa.match("acccc"))
        XCTAssertTrue(dfa.match("abbccbbccbc"))

        XCTAssertFalse(dfa.match("aa"))
        XCTAssertFalse(dfa.match("aba"))
        XCTAssertFalse(dfa.match("abac"))
        XCTAssertFalse(dfa.match("abbccbbccbca"))
    }

    func testRegularExpressionToDFAMatch() {
        // a(b|c)* - should match a, ab, ac, abc, abbbb, acccc, abbccbcbbc, etc
        let re: RegularExpression = "a" + ("b" | "c")*
        let dfa = re.nfa.dfa
        
        XCTAssertTrue(dfa.match("a"))
        XCTAssertTrue(dfa.match("ab"))
        XCTAssertTrue(dfa.match("ac"))
        XCTAssertTrue(dfa.match("abc"))
        XCTAssertTrue(dfa.match("acb"))
        XCTAssertTrue(dfa.match("abbbb"))
        XCTAssertTrue(dfa.match("acccc"))
        XCTAssertTrue(dfa.match("abbccbbccbc"))
        
        XCTAssertFalse(dfa.match("aa"))
        XCTAssertFalse(dfa.match("aba"))
        XCTAssertFalse(dfa.match("abac"))
        XCTAssertFalse(dfa.match("abbccbbccbca"))
        XCTAssertFalse(dfa.match("cbcab"))
    }

    func testRegularExpressionToMinimizedDFAMatch() {
        // a(b|c)* - should match a, ab, ac, abc, abbbb, acccc, abbccbcbbc, etc
        let re: RegularExpression = "a" + ("b" | "c")*
        let dfa = re.nfa.dfa.minimized

        XCTAssertTrue(dfa.match("a"))
        XCTAssertTrue(dfa.match("ab"))
        XCTAssertTrue(dfa.match("ac"))
        XCTAssertTrue(dfa.match("abc"))
        XCTAssertTrue(dfa.match("acb"))
        XCTAssertTrue(dfa.match("abbbb"))
        XCTAssertTrue(dfa.match("acccc"))
        XCTAssertTrue(dfa.match("abbccbbccbc"))
        
        XCTAssertFalse(dfa.match("aa"))
        XCTAssertFalse(dfa.match("aba"))
        XCTAssertFalse(dfa.match("abac"))
        XCTAssertFalse(dfa.match("abbccbbccbca"))
        XCTAssertFalse(dfa.match("cbcab"))
    }
    
    func testMultiAcceptingStatesDFA() {
        enum Token { case aa, ab, ac, unknown }
        
        let dfa = DFA<Token>(
            vertices: 5,
            edges: [
                DFA.Edge(from: 0, scalar: .single("a")): 1,
                DFA.Edge(from: 1, scalar: .single("a")): 2,
                DFA.Edge(from: 1, scalar: .single("b")): 3,
                DFA.Edge(from: 1, scalar: .single("c")): 4,
            ],
            initial: 0,
            accepting: [2: .aa, 3: .ab, 4: .ac],
            nonAcceptingValue: .unknown
        )
        
        XCTAssertEqual(dfa.match("aa"), .aa)
        XCTAssertEqual(dfa.match("ab"), .ab)
        XCTAssertEqual(dfa.match("ac"), .ac)
        XCTAssertEqual(dfa.match("bb"), .unknown)
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
            let dfa = NFA<Token>(scanner: scanner, nonAcceptingValue: .unknown)
                        .dfa.minimized

            XCTAssertEqual(dfa.match("134"), .integer)
            XCTAssertEqual(dfa.match("61.613"), .decimal)
            XCTAssertEqual(dfa.match("x1"), .identifier)
            XCTAssertEqual(dfa.match("1xy"), .unknown)
        }
    }

    static var allTests = [
        ("testNFA", testNFA),
        ("testRegularExpression", testRegularExpression),
        ("testDFA", testDFA),
        ("testRegularExpressionToDFAMatch", testRegularExpressionToDFAMatch),
        ("testRegularExpressionToMinimizedDFAMatch", testRegularExpressionToMinimizedDFAMatch),
    ]
}
