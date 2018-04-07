import XCTest
@testable import CompilerKit

final class FiniteStateTests: XCTestCase {
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
            accepting: [3: true]
        )
        XCTAssertTrue(nfa.match("aaab".unicodeScalars).contains(true))
        XCTAssertFalse(nfa.match("aaa".unicodeScalars).contains(true))
        XCTAssertTrue(nfa.match("ab".unicodeScalars).contains(true))
        XCTAssertFalse(nfa.match("b".unicodeScalars).contains(true))
        XCTAssertFalse(nfa.match("bbbbab".unicodeScalars).contains(true))
    }
    
    
    func testRegularExpression() {
        // a*ab - should match ab, aab, aaab, etc
        let re: RegularExpression = "a"* + ("a" + "b")
        let derivedNfa = re.nfa
        XCTAssertTrue(derivedNfa.match("aaab".unicodeScalars).contains(true))
        XCTAssertFalse(derivedNfa.match("aaa".unicodeScalars).contains(true))
        XCTAssertTrue(derivedNfa.match("ab".unicodeScalars).contains(true))
        XCTAssertFalse(derivedNfa.match("b".unicodeScalars).contains(true))
        XCTAssertFalse(derivedNfa.match("bbbbab".unicodeScalars).contains(true))
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
        let dfa = DFA(consistent: re.nfa, nonAcceptingValue: false)!
        
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
        let dfa = DFA(consistent: re.nfa, nonAcceptingValue: false)!.minimized
        
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
        }
        
        let scanner: [(RegularExpression, Token)] = [
            (.digit + .digit*, .integer),
            (.digit + .digit* + "." + .digit + .digit*, .decimal),
            (.alpha + .alphanum*, .identifier),
            ]
        
        measure {
            let dfa = NFA<Token, ScalarClass>(scanner: scanner)
                .dfa.minimized
            
            XCTAssertEqual(dfa.match("134".unicodeScalars), [.integer])
            XCTAssertEqual(dfa.match("61.613".unicodeScalars), [.decimal])
            XCTAssertEqual(dfa.match("x1".unicodeScalars), [.identifier])
            XCTAssertEqual(dfa.match("1xy".unicodeScalars), [])
        }
    }
}
