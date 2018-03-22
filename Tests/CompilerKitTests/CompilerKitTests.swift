import XCTest
@testable import CompilerKit

final class CompilerKitTests: XCTestCase {
    func testNFA() {
        // a*ab - should match ab, aab, aaab, etc
        let nfa = NFA(
            vertices: 4,
            edges: [
                NFA.Edge(from: 0, to: 0, scalar: "a"),
                NFA.Edge(from: 0, to: 1, scalar: nil),
                NFA.Edge(from: 1, to: 2, scalar: "a"),
                NFA.Edge(from: 2, to: 3, scalar: "b")
            ],
            initial: 0,
            accepting: 3)
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
                DFA.Edge(from: 0, scalar: "a"): 1,
                DFA.Edge(from: 1, scalar: "b"): 1,
                DFA.Edge(from: 1, scalar: "c"): 1
            ],
            initial: [0],
            accepting: [1]
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
    
    static var allTests = [
        ("testNFA", testNFA),
        ("testRegularExpression", testRegularExpression),
        ("testDFA", testDFA),
        ("testRegularExpressionToDFAMatch", testRegularExpressionToDFAMatch),
        ("testRegularExpressionToMinimizedDFAMatch", testRegularExpressionToMinimizedDFAMatch),
    ]
}
