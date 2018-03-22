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
    
    func match(_ s: String) -> Bool {
        var states: Set<Int> = [initial]
        for scalar in s.unicodeScalars {
            // add all states reachable by epsilon transitions
            var exploreNext: [Int] = Array(states)
            while let explore = exploreNext.popLast() {
                let newReachableStates = edges
                        .filter { $0.from == explore && !states.contains($0.to) && $0.scalar == nil }
                        .map { $0.to }
                exploreNext.append(contentsOf: newReachableStates)
                states.formUnion(newReachableStates)
            }
            
            // new set of states as allowed by current scalar in string
            states = Set(edges
                .filter { states.contains($0.from) && $0.scalar == scalar }
                .map { $0.to })
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

