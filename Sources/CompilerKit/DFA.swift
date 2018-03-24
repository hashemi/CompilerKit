struct DFA<T> {
    struct Edge: Hashable {
        let from: Int
        let scalar: UnicodeScalar
    }
    
    var alphabet: Set<UnicodeScalar> {
        return Set(edges.keys.map { $0.scalar })
    }
    
    let vertices: Int
    let edges: [Edge: Int]
    let initial: Int
    let accepting: [Int: T]
    let nonAcceptingValue: T
    
    func match(_ s: String) -> T {
        var state = initial
        for scalar in s.unicodeScalars {
            guard let newState = edges[Edge(from: state, scalar: scalar)] else {
                return nonAcceptingValue
            }
            state = newState
        }
        return accepting[state] ?? nonAcceptingValue
    }
}

// minimal dfa (Hopcroft's Algorithm)
extension DFA {
    var minimized: DFA {
        let alphabet = self.alphabet
        
        // start with partitions: 0 = non-accepting states, and a separate bucket for each accepting state
        var partitionCount = 1
        var partition = (0..<self.vertices).map { (v: Int) -> Int in
            if self.accepting.keys.contains(v) {
                partitionCount += 1
                return partitionCount - 1
            } else {
                return 0
            }
        }
        
        func split() {
            for scalar in alphabet {
                // -1: not set yet, -2: no path exists from this partition for this scalar
                var partitionTarget = Array(repeating: -1, count: partitionCount)
                var newPartition = Array(repeating: -1, count: partitionCount)
                for x in 0..<self.vertices {
                    let p = partition[x]
                    let target: Int
                    if let nextState = self.edges[Edge(from: x, scalar: scalar)] {
                        target = partition[nextState]
                    } else {
                        target = -2
                    }
                    
                    if partitionTarget[p] == -1 {
                        // first item in partition
                        partitionTarget[p] = target
                        continue
                    } else {
                        if partitionTarget[p] != target {
                            if newPartition[p] == -1 {
                                newPartition[p] = partitionCount
                                partitionCount += 1
                            }
                            
                            partition[x] = newPartition[p]
                        }
                    }
                }
            }
        }
        
        var lastPartitionCount = 0
        while partitionCount != lastPartitionCount {
            lastPartitionCount = partitionCount
            split()
        }
        
        let initial = partition[self.initial]
        let accepting = Dictionary(uniqueKeysWithValues: self.accepting.map { (partition[$0.key], $0.value) })
        let edges = Dictionary(
            self.edges.map { edge, target in
            (Edge(from: partition[edge.from], scalar: edge.scalar), partition[target]) }, uniquingKeysWith: { (first, _ ) in first })
        
        return DFA(vertices: partitionCount, edges: edges, initial: initial, accepting: accepting, nonAcceptingValue: self.nonAcceptingValue)
    }
}
