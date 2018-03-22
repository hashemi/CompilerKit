struct NFA {
    struct Edge {
        let from: Int
        let to: Int
        let scalar: UnicodeScalar?
    }
    
    let vertices: Int
    let edges: [Edge]
    let initial: Int
    let accepting: Int
    
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
    
    func match(_ s: String) -> Bool {
        var states: Set<Int> = [initial]
        for scalar in s.unicodeScalars {
            // add all states reachable by epsilon transitions
            states = epsilonClosure(from: states)
            
            // new set of states as allowed by current scalar in string
            states = reachable(from: states, via: scalar)
        }
        return states.contains(accepting)
    }
    
    func offset(by offset: Int) -> NFA {
        return NFA(
            vertices: vertices + offset,
            edges: edges.map { Edge(from: $0.from + offset, to: $0.to + offset, scalar: $0.scalar) },
            initial: initial + offset,
            accepting: accepting + offset
        )
    }
}

// DFA from NFA (subset construction)
extension NFA {
    var dfa: DFA {
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
        let edges: [DFA.Edge] = T.map { t in
            DFA.Edge(from: qPositions[t.from]!, to: qPositions[t.to]!, scalar: t.scalar)
        }
        let initial: Set<Int> = [0] // this is always zero since we always add q0 first to Q
        let accepting = Set(Q.enumerated().filter { $0.element.contains(self.accepting) }.map { $0.offset })
        
        return DFA(vertices: vertices, edges: edges, initial: initial, accepting: accepting)
    }
}
