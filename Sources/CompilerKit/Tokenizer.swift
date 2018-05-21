struct Tokenizer<Output> where Output: Hashable {
    let dfa: DFA<Output, ScalarClass>
    let trivia: DFA<Bool, ScalarClass>
    let unknown: Output
    
    init?(tokens: [(RegularExpression, Output)], trivia: RegularExpression, unknown: Output) {
        let nfa = NFA<Output, ScalarClass>(scanner: tokens)
        guard let dfa = DFA(consistent: nfa, nonAcceptingValue: unknown)
            else { return nil }
        self.dfa = dfa.minimized
        
        guard let triviaDFA = DFA(consistent: trivia.nfa, nonAcceptingValue: false)
            else { return nil }
        self.trivia = triviaDFA.minimized
        
        self.unknown = unknown
    }
    
    func tokenize(_ source: String.UnicodeScalarView) -> [(Output, Substring.UnicodeScalarView.SubSequence)] {
        var tokens: [(Output, Substring.UnicodeScalarView.SubSequence)] = []
        var offset = source.startIndex
        var unknownStart: String.UnicodeScalarView.Index? = nil
        
        func processUnknown() {
            if unknownStart != nil {
                tokens.append((unknown, source[unknownStart!..<offset]))
                unknownStart = nil
            }
        }
        
        while true {
            let (hasTrivia, triviaMatch) = trivia.prefixMatch(source[offset...])
            if hasTrivia {
                // we've been skipping over an unknown segment until we reached trivia
                processUnknown()
                offset = triviaMatch.endIndex
            }
            
            // reached end of string, we can stop
            if offset == source.endIndex {
                processUnknown()
                break
            }
            
            // we are in an unknown state, keep moving until we find trivia or end of string
            if unknownStart != nil {
                offset = source.index(after: offset)
                continue
            }
            
            let (token, match) = dfa.prefixMatch(source[offset...])
            
            // if we couldn't recognize a known token, enter the unknown state
            if token == unknown {
                unknownStart = offset
                offset = source.index(after: offset)
                continue
            }
            
            tokens.append((token, match))
            offset = match.endIndex
        }
        
        return tokens
    }
}
