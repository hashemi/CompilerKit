struct DFA<Output, M: Matcher & Hashable> {
    typealias Element = M.Element
    
    struct Transition: Hashable {
        let from: Int
        let matcher: M
    }
    
    var alphabet: Set<M> {
        return Set(transitions.keys.map { $0.matcher })
    }
    
    let states: Int
    let transitions: [Transition: Int]
    let initial: Int
    let accepting: [Int: Output]
    let nonAcceptingValue: Output
    
    func match<S: Sequence>(_ elements: S) -> Output where S.Element == Element {
        var state = initial
        for element in elements {
            guard let matcher = alphabet.first(where: { $0 ~= element }) else {
                return nonAcceptingValue
            }
            
            guard let newState = transitions[Transition(from: state, matcher: matcher)] else {
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
        let (partitionCount, partition) = partitionByAcceptingState()
        return minimized(partitionCount, partition)
    }
    
    func partitionByAcceptingState() -> (Int, [Int]) {
        // start with partitions: 0 = non-accepting states, and a separate bucket for each accepting state
        var partitionCount = 1
        let partition = (0..<self.states).map { (v: Int) -> Int in
            if self.accepting.keys.contains(v) {
                partitionCount += 1
                return partitionCount - 1
            } else {
                return 0
            }
        }
        return (partitionCount, partition)
    }
    
    func minimized(_ partitionCount: Int, _ partition: [Int]) -> DFA {
        var partitionCount = partitionCount
        var partition = partition
        
        let alphabet = self.alphabet
        func split() {
            for matcher in alphabet {
                // -1: not set yet, -2: no path exists from this partition for this scalar
                var partitionTarget = Array(repeating: -1, count: partitionCount)
                var newPartition = Array(repeating: -1, count: partitionCount)
                for x in 0..<self.states {
                    let p = partition[x]
                    let target: Int
                    if let nextState = self.transitions[Transition(from: x, matcher: matcher)] {
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
        let accepting = Dictionary(
            self.accepting.map { (partition[$0.key], $0.value) },
            uniquingKeysWith: { (first, _) in first })
        let transitions = Dictionary(
            self.transitions.map { transition, target in
                (Transition(from: partition[transition.from], matcher: transition.matcher), partition[target]) }, uniquingKeysWith: { (first, _ ) in first })
        
        return DFA(states: partitionCount, transitions: transitions, initial: initial, accepting: accepting, nonAcceptingValue: self.nonAcceptingValue)
    }
}

// when accepting values are equatable, we can combine accepting states by value
extension DFA where Output: Equatable {
    var minimized: DFA {
        let (partitionCount, partition) = partitionByAcceptingState()
        return minimized(partitionCount, partition)
    }
    
    func partitionByAcceptingState() -> (Int, [Int]) {
        // placing nonAcceptingValue at position 0 makes off-by-one errors less likely
        var partitionsAcceptingValue: [Output] = [nonAcceptingValue]
        
        // 0 = non-accepting states, and separate bucket for each accepting state that produces a different value
        let partition = (0..<self.states).map { (v: Int) -> Int in
            guard let acceptingValue = self.accepting[v] else {
                return 0 // this vertex is not an accepting state, it stays in partition 0
            }
            
            // this accepting value already has a partition, return it
            if let p = partitionsAcceptingValue.index(of: acceptingValue) {
                return p
            }
            
            // need to give the value a partition
            partitionsAcceptingValue.append(acceptingValue)
            
            return partitionsAcceptingValue.count - 1
        }
        return (partitionsAcceptingValue.count, partition)
    }
}
