struct DFA<Output: Hashable, M: Matcher & Hashable> {
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

extension DFA {
    init<NFAOutput: Hashable>(_ nfa: NFA<NFAOutput, M>) where Output == Set<NFAOutput> {
        // precompute and cache epsilon closures
        let epsilonClosures = nfa.epsilonClosures
        
        func epsilonClosure(from states: Set<Int>) -> Set<Int> {
            var all = Set<Int>()
            for v in states {
                all.formUnion(epsilonClosures[v])
            }
            return all
        }
        
        let alphabet = nfa.alphabet
        let q0 = epsilonClosures[nfa.initial]
        var Q: [Set<Int>] = [q0]
        var worklist = [(0, q0)]
        var transitions: [DFA<Set<NFAOutput>, M>.Transition: Int] = [:]
        var accepting: [Int: Set<NFAOutput>] = [0: Set(q0.compactMap { nfa.accepting[$0] })]
        while let (qpos, q) = worklist.popLast() {
            for matcher in alphabet {
                let t = nfa.epsilonClosure(from: nfa.reachable(from: q, via: matcher))
                if t.isEmpty { continue }
                let position = Q.index(of: t) ?? Q.count
                if position == Q.count {
                    Q.append(t)
                    worklist.append((position, t))
                    accepting[Q.count - 1] = Set(t.compactMap({ nfa.accepting[$0] }))
                }
                transitions[DFA<Set<NFAOutput>, M>.Transition(from: qpos, matcher: matcher)] = position
            }
        }
        
        self.init(
            states: Q.count,
            transitions: transitions,
            initial: 0, // this is always zero since q0 is always the first item in Q
            accepting: accepting,
            nonAcceptingValue: Set<NFAOutput>()
        )
    }
    
    init?(consistent nfa: NFA<Output, M>, nonAcceptingValue: Output) {
        let dfa = DFA<Set<Output>, M>(nfa)
        
        var accepting: [Int: Output] = [:]
        for (k,v) in dfa.accepting {
            switch v.count {
            case 0: break
            case 1: accepting[k] = v.first!
            default: return nil
            }
        }
        
        let transitions = Dictionary(uniqueKeysWithValues:
            dfa.transitions.map { k,v in
                (Transition(from: k.from, matcher: k.matcher), v)
            }
        )
        
        self.states = dfa.states
        self.transitions = transitions
        self.initial = dfa.initial
        self.accepting = accepting
        self.nonAcceptingValue = nonAcceptingValue
    }
}

// minimal dfa (Hopcroft's Algorithm)
extension DFA {
    var minimized: DFA {
        // create a canonical partition per unique accepting value
        let acceptingPartition = Dictionary(uniqueKeysWithValues:
            Set(self.accepting.values)
                .enumerated()
                .map { ($0.element, $0.offset + 1) }
        )
        
        // 0 = non-accepting states, otherwise location is determined by acceptingPartition
        var partition = (0..<self.states).map { (s: Int) -> Int in
            guard let acceptingValue = self.accepting[s] else { return 0 }
            return acceptingPartition[acceptingValue]!
        }
        
        var partitionCount = acceptingPartition.count + 1
        
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
