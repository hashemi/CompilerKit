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

