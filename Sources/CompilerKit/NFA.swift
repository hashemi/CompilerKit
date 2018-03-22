struct NFA {
    struct Edge {
        let from: Int
        let to: Int
        let scalar: UnicodeScalar?
    }
    
    let vertices: Int
    let edges: [Edge]
    let s0: Int = 0
    let accepting: Int
    
    func match(_ s: String) -> Bool {
        var states: Set<Int> = [s0]
        for scalar in s.unicodeScalars {
            // expand states by epsilon transitions
            states.formUnion(
                edges
                    .filter { states.contains($0.from) && $0.scalar == nil }
                    .map { $0.to })
            
            // new set of states is states reachable from current set of states by through current scalar in string
            states = Set(edges
                .filter { states.contains($0.from) && $0.scalar == scalar }
                .map { $0.to })
        }
        return states.contains(accepting)
    }
}

