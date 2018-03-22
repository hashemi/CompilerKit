indirect enum RegularExpression {
    case scalar(UnicodeScalar)
    case alternation(RegularExpression, RegularExpression)
    case concatenation(RegularExpression, RegularExpression)
    case closure(RegularExpression)
}

// A more convenient way for building a regular expression in Swift code
postfix operator *

extension RegularExpression: ExpressibleByUnicodeScalarLiteral {
    init(unicodeScalarLiteral scalar: UnicodeScalar) {
        self = .scalar(scalar)
    }
    
    static func +(lhs: RegularExpression, rhs: RegularExpression) -> RegularExpression {
        return .concatenation(lhs, rhs)
    }
    
    static func |(lhs: RegularExpression, rhs: RegularExpression) -> RegularExpression {
        return .alternation(lhs, rhs)
    }
    
    static postfix func *(re: RegularExpression) -> RegularExpression {
        return .closure(re)
    }
}

// Derive an NFA from a regular expression (Thompson's Construction)
extension RegularExpression {
    var nfa: NFA {
        switch self {
        case .scalar(let scalar):
            return NFA(vertices: 2, edges: [NFA.Edge(from: 0, to: 1, scalar: scalar)], initial: 0, accepting: 1)
        
        case .concatenation(let re1, let re2):
            let nfa1 = re1.nfa
            let nfa2 = re2.nfa
            
            // nfa1 followed by nfa2 with episilon transition between them
            let nfa2offset = nfa2.offset(by: nfa1.vertices)
            let edges = nfa1.edges
                + nfa2offset.edges
                + [NFA.Edge(from: nfa1.accepting, to: nfa2offset.initial, scalar: nil)]
            return NFA(
                vertices: nfa2offset.vertices,
                edges: edges,
                initial: nfa1.initial,
                accepting: nfa2offset.accepting)
        
        case .alternation(let re1, let re2):
            let nfa1 = re1.nfa
            let nfa2 = re2.nfa
            
            // create a common initial state that points to each nfa's initial
            // with an epsilon edge and a common accepting state from each nfa's
            // accepting state
            let nfa1offset = nfa1.offset(by: 1)
            let nfa2offset = nfa2.offset(by: nfa1.vertices + 1)
            
            let vertices = nfa2offset.vertices + 1
            let initial = 0
            let accepting = vertices - 1
            
            let edges = nfa1offset.edges
                + nfa2offset.edges
                + [
                    NFA.Edge(from: 0, to: nfa1offset.initial, scalar: nil),
                    NFA.Edge(from: 0, to: nfa2offset.initial, scalar: nil),
                    NFA.Edge(from: nfa1offset.accepting, to: accepting, scalar: nil),
                    NFA.Edge(from: nfa2offset.accepting, to: accepting, scalar: nil)
                ]
            return NFA(vertices: vertices, edges: edges, initial: initial, accepting: accepting)
            
        case .closure(let re):
            let nfa = re.nfa
            let offset = nfa.offset(by: 1)
            
            // close over NFA with a new initial and accepting states, and add edges to allow:
            // - skipping the NFA by going from initial to accepting directly
            // - going through NFA by connecting our initial and accepting states to those of NFA
            // - looping over NFA many times by connecting NFAs accepting state to its initial state
            let vertices = offset.vertices + 1
            let initial = 0
            let accepting = vertices - 1
            let edges = offset.edges
                + [
                    NFA.Edge(from: initial, to: accepting, scalar: nil),
                    NFA.Edge(from: initial, to: offset.initial, scalar: nil),
                    NFA.Edge(from: offset.accepting, to: offset.initial, scalar: nil),
                    NFA.Edge(from: offset.accepting, to: accepting, scalar: nil)
                ]
            return NFA(vertices: vertices, edges: edges, initial: initial, accepting: accepting)
        }
    }
}
