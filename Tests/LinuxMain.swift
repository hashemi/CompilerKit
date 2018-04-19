@testable import CompilerKitTests
import XCTest

extension FiniteStateTests {
    static var allTests: [(String, (FiniteStateTests) -> () throws -> Void)] = [
        ("testNFA", testNFA),
        ("testRegularExpression", testRegularExpression),
        ("testDFA", testDFA),
        ("testRegularExpressionToDFAMatch", testRegularExpressionToDFAMatch),
        ("testRegularExpressionToMinimizedDFAMatch", testRegularExpressionToMinimizedDFAMatch),
        ("testMultiAcceptingStatesDFA", testMultiAcceptingStatesDFA),
        ("testScanner", testScanner),
    ]
}

extension GrammarTests {
    static var allTests: [(String, (GrammarTests) -> () throws -> Void)] = [
        ("testGrammar", testGrammar),
        ("testLLParserConstruction", testLLParserConstruction),
        ("testLLParserCorrectness", testLLParserCorrectness),
        ("testLRConstruction", testLRConstruction),
        ("testLRParserCorrectness", testLRParserCorrectness),
        ("testLALRParserCorrectness", testLALRParserCorrectness),
        ("testBacktrackingGrammar", testBacktrackingGrammar),
        ("testLALR", testLALR),
    ]
}

XCTMain([
		testCase(FiniteStateTests.allTests),
		testCase(GrammarTests.allTests),
	])
