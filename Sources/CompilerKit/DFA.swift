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

// minimal dfa (Hopcroft's Algorithm)
extension DFA {
    var minimized: DFA {
        let alphabet = self.alphabet
        
        // start with two partitions, 0 = non-accepting states, 1 = accepting states
        var partition = (0..<self.vertices).map { self.accepting.contains($0) ? 1 : 0 }
        var partitionCount = 2
        
        func split(p: Int) {
            for scalar in alphabet {
                // -1: not set yet, -2: no path exists from this partition for this scalar
                var partitionTarget = -1
                var splitting = false
                for x in 0..<self.vertices where partition[x] == p {
                    let target: Int
                    if let nextState = self.edges[Edge(from: x, scalar: scalar)] {
                        target = partition[nextState]
                    } else {
                        target = -2
                    }
                    
                    if partitionTarget == -1 {
                        // first item in partition
                        partitionTarget = target
                        continue
                    } else {
                        if partitionTarget != target {
                            if !splitting {
                                splitting = true
                                partitionCount += 1
                            }
                            
                            partition[x] = partitionCount - 1
                        }
                    }
                }
                if splitting { return }
            }
        }
        
        var lastPartitionCount = 0
        while partitionCount != lastPartitionCount {
            lastPartitionCount = partitionCount
            for p in 0..<partitionCount { split(p: p) }
        }
        
        let initial = Set(self.initial.map { partition[$0] })
        let accepting = Set(self.accepting.map { partition[$0] })
        let edges = Dictionary(
            self.edges.map { edge, target in
            (Edge(from: partition[edge.from], scalar: edge.scalar), partition[target]) }, uniquingKeysWith: { (first, _ ) in first })
        
        return DFA(vertices: partitionCount, edges: edges, initial: initial, accepting: accepting)
    }
}
