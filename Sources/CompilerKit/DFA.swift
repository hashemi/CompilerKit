struct DFA {
    struct Edge: Hashable {
        let from: Int
        let scalar: UnicodeScalar
    }
    
    var alphabet: Set<UnicodeScalar> {
        return Set(edges.keys.map { $0.scalar })
    }
    
    let vertices: Int
    let edges: [Edge: Int]
    let initial: Set<Int>
    let accepting: Set<Int>

    func match(_ s: String) -> Bool {
        var states: Set<Int> = initial
        for scalar in s.unicodeScalars {
            // new set of states as allowed by current scalar in string
            states = Set(states.compactMap { edges[Edge(from: $0, scalar: scalar)] })
        }
        return !states.isDisjoint(with: accepting)
    }
}

