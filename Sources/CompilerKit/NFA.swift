struct NFA<T> {
    struct Edge {
        let from: Int
        let to: Int
        let scalar: UnicodeScalar?
    }
    
    let vertices: Int
    let edges: [Edge]
    let initial: Int
    let accepting: [Int: T]
    let nonAcceptingValue: T
    
    var alphabet: Set<UnicodeScalar> {
        return edges.reduce(into: Set<UnicodeScalar>(), { set, edge in
            if let scalar = edge.scalar { set.insert(scalar) }
        })
    }
    
    func epsilonClosure(from states: Set<Int>) -> Set<Int> {
        var newStates = states
        var worklist = Array(states)
        while let state = worklist.popLast() {
            let newReachableStates = edges
                .filter { $0.from == state && !newStates.contains($0.to) && $0.scalar == nil }
                .map { $0.to }
            worklist.append(contentsOf: newReachableStates)
            newStates.formUnion(newReachableStates)
        }
        return newStates
    }
    
    func reachable(from states: Set<Int>, via scalar: UnicodeScalar) -> Set<Int> {
        return Set(edges
            .filter { states.contains($0.from) && $0.scalar == scalar }
            .map { $0.to })
    }
    
    func match(_ s: String) -> T {
        var states: Set<Int> = [initial]
        for scalar in s.unicodeScalars {
            // add all states reachable by epsilon transitions
            states = epsilonClosure(from: states)
            
            // new set of states as allowed by current scalar in string
            states = reachable(from: states, via: scalar)
        }
        return states.compactMap { self.accepting[$0] }.first ?? nonAcceptingValue
    }
    
    func offset(by offset: Int) -> NFA {
        return NFA(
            vertices: vertices + offset,
            edges: edges.map { Edge(from: $0.from + offset, to: $0.to + offset, scalar: $0.scalar) },
            initial: initial + offset,
            accepting: Dictionary(uniqueKeysWithValues: accepting.map { ($0.key + offset, $0.value) }),
            nonAcceptingValue: nonAcceptingValue
        )
    }
}

// DFA from NFA (subset construction)
extension NFA {
    var dfa: DFA<T> {
        let alphabet = self.alphabet
        let q0 = epsilonClosure(from: [self.initial])
        var Q: [Set<Int>] = [q0]
        var worklist = [q0]
        var T: [(from: Set<Int>, to: Set<Int>, scalar: UnicodeScalar)] = []
        while let q = worklist.popLast() {
            for scalar in alphabet {
                let t = epsilonClosure(from: reachable(from: q, via: scalar))
                if t.isEmpty { continue }
                T.append((from: q, to: t, scalar: scalar))
                if !Q.contains(t) {
                    Q.append(t)
                    worklist.append(t)
                }
            }
        }
        
        // create a dictionary that maps sets to their positions in Q
        let qPositions = Dictionary<Set<Int>, Int>(uniqueKeysWithValues: Q.enumerated().map { ($0.element, $0.offset) })

        let vertices = Q.count
        
        let edges = Dictionary(uniqueKeysWithValues: T.map { t in
            (DFA<T>.Edge(from: qPositions[t.from]!, scalar: t.scalar), qPositions[t.to]!)
        })
        
        let initial = 0 // this is always zero since we always add q0 first to Q
        let accepting = Dictionary(uniqueKeysWithValues: Q.enumerated().compactMap { (i, q) -> (Int, T)? in
            if let value = q.compactMap({ self.accepting[$0] }).first {
                return (i, value)
            } else {
                return nil
            }
        })
        
        return DFA(vertices: vertices, edges: edges, initial: initial, accepting: accepting, nonAcceptingValue: self.nonAcceptingValue)
    }
}

// Initialize NFA from RE
extension NFA {
    init(re: RegularExpression, acceptingValue: T, nonAcceptingValue: T) {
        switch re {
        case .scalar(let scalar):
             self.init(
                vertices: 2,
                edges: [Edge(from: 0, to: 1, scalar: scalar)],
                initial: 0,
                accepting: [1: acceptingValue],
                nonAcceptingValue: nonAcceptingValue
            )

        
        case .concatenation(let re1, let re2):
            let nfa1 = NFA(re: re1, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            let nfa2 = NFA(re: re2, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            
            // nfa1 followed by nfa2 with episilon transition between them
            let nfa2offset = nfa2.offset(by: nfa1.vertices)
            let edges = nfa1.edges
                + nfa2offset.edges
                + nfa1.accepting.keys.map { Edge(from: $0, to: nfa2offset.initial, scalar: nil) }
            
            self.init(
                vertices: nfa2offset.vertices,
                edges: edges,
                initial: nfa1.initial,
                accepting: nfa2offset.accepting,
                nonAcceptingValue: nonAcceptingValue
            )


        case .alternation(let re1, let re2):
            let nfa1 = NFA(re: re1, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            let nfa2 = NFA(re: re2, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            
            // create a common initial state that points to each nfa's initial
            // with an epsilon edge and a combined accepting dictionary
            let nfa1offset = nfa1.offset(by: 1)
            let nfa2offset = nfa2.offset(by: nfa1.vertices + 1)
            
            let vertices = nfa2offset.vertices
            let initial = 0
            
            let edges = nfa1offset.edges
                + nfa2offset.edges
                + [
                    NFA.Edge(from: 0, to: nfa1offset.initial, scalar: nil),
                    NFA.Edge(from: 0, to: nfa2offset.initial, scalar: nil),
                ]
            
            let accepting = nfa1offset.accepting.merging(nfa2offset.accepting, uniquingKeysWith: { first, _ in first })
            
            self.init(
                vertices: vertices,
                edges: edges,
                initial: initial,
                accepting: accepting,
                nonAcceptingValue: nonAcceptingValue
            )


        case .closure(let re):
            let nfa = NFA(re: re, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            
            // turn nfa into a closure by:
            // - make intial state accepting, to allow skipping the NFA (zero occurences)
            // - looping over NFA many times by connecting NFAs accepting states to its initial state
            let accepting = nfa.accepting.merging([nfa.initial: acceptingValue], uniquingKeysWith: { first, _ in first })
            let edges = nfa.edges + nfa.accepting.keys.map { Edge(from: $0, to: nfa.initial, scalar: nil) }
            
            self.init(
                vertices: nfa.vertices,
                edges: edges,
                initial: nfa.initial,
                accepting: accepting,
                nonAcceptingValue: nonAcceptingValue
            )
        }
    }
}
