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
            states.formUnion(
                edges
                    .filter { states.contains($0.from) && $0.scalar == nil }
                    .map { $0.to })
            
            // new set of states as allowed by current scalar in string
            states = Set(edges
                .filter { states.contains($0.from) && $0.scalar == scalar }
                .map { $0.to })
        }
        return states.contains(accepting)
    }
}

