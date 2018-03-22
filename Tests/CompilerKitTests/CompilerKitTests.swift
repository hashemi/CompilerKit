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
            accepting: 3)
        XCTAssertTrue(nfa.match("aaab"))
        XCTAssertFalse(nfa.match("aaa"))
        XCTAssertTrue(nfa.match("ab"))
        XCTAssertFalse(nfa.match("b"))
        XCTAssertFalse(nfa.match("bbbbab"))
    }


    static var allTests = [
        ("testNFA", testNFA),
    ]
}
