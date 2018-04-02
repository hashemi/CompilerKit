struct NFA<Output> {
    let states: Int
    let transitions: [ScalarClass: [(Int, Int)]]
    let epsilonTransitions: [Int: [Int]]
    let initial: Int
    let accepting: [Int: Output]
    let nonAcceptingValue: Output
    
    var epsilonClosures: [Set<Int>] {
        var epsilonClosures: [Set<Int>] = []
        
        for v in 0..<states {
            var marked = Set<Int>()
            
            func dfs(_ s: Int) {
                marked.insert(s)
                for w in epsilonTransitions[s, default: []] {
                    if !marked.contains(w) { dfs(w) }
                }
            }
            
            dfs(v)
            
            epsilonClosures.append(marked)
        }
        
        return epsilonClosures
    }
    
    var alphabet: Dictionary<ScalarClass, [(Int, Int)]>.Keys {
        return transitions.keys
    }

    func epsilonClosure(from states: Set<Int>) -> Set<Int> {
        var marked = Set<Int>()
        
        func dfs(_ s: Int) {
            marked.insert(s)
            for w in epsilonTransitions[s, default: []] {
                if !marked.contains(w) { dfs(w) }
            }
        }
        
        for s in states {
            if !marked.contains(s) { dfs(s) }
        }
        
        return marked
    }

    func reachable(from states: Set<Int>, via scalarClass: ScalarClass) -> Set<Int> {
        var set = Set<Int>()
        for (from, to) in transitions[scalarClass, default: []] {
            if states.contains(from) {
                set.insert(to)
            }
        }
        return set
    }
    
    func match(_ s: String) -> Output {
        var states = Set<Int>()
        states.insert(initial)
        for scalar in s.unicodeScalars {
            // add all states reachable by epsilon transitions
            states = epsilonClosure(from: states)
            
            guard let scalarClass = alphabet.first(where: { $0 ~= scalar }) else {
                return nonAcceptingValue
            }
            
            // new set of states as allowed by current scalar in string
            states = reachable(from: states, via: scalarClass)
            
            if states.isEmpty { return nonAcceptingValue }
        }
        return states.compactMap { self.accepting[$0] }.first ?? nonAcceptingValue
    }
    
    func offset(by offset: Int) -> NFA {
        return NFA(
            states: states + offset,
            transitions: transitions.mapValues { $0.map { from, to in (from + offset, to + offset) } },
            epsilonTransitions: Dictionary(uniqueKeysWithValues: epsilonTransitions.map { ($0.key + offset, $0.value.map { $0 + offset }) }),
            initial: initial + offset,
            accepting: Dictionary(uniqueKeysWithValues: accepting.map { ($0.key + offset, $0.value) }),
            nonAcceptingValue: nonAcceptingValue
        )
    }
}

extension NFA {
    init(alternatives: [NFA<Output>], nonAcceptingValue: Output) {
        let commonInitial = 0
        var states = 1
        var transitions: [ScalarClass: [(Int, Int)]] = [:]
        var epsilonTransitions: [Int: [Int]] = [:]
        var accepting: [Int: Output] = [:]
        
        for nfa in alternatives {
            let offset = nfa.offset(by: states)
            transitions.merge(offset.transitions, uniquingKeysWith: { $0 + $1 })
            epsilonTransitions.merge(offset.epsilonTransitions, uniquingKeysWith: { first, _ in first })
            epsilonTransitions[commonInitial, default: []].append(offset.initial)
            accepting.merge(offset.accepting, uniquingKeysWith: { first, _ in first })
            states = offset.states
        }
        
        self.init(
            states: states,
            transitions: transitions,
            epsilonTransitions: epsilonTransitions,
            initial: commonInitial,
            accepting: accepting,
            nonAcceptingValue: nonAcceptingValue
        )
    }
    
    init(scanner: [(RegularExpression, Output)], nonAcceptingValue: Output) {
        let alternatives = scanner.map { NFA(re: $0.0, acceptingValue: $0.1, nonAcceptingValue: nonAcceptingValue) }
        self.init(alternatives: alternatives, nonAcceptingValue: nonAcceptingValue)
    }
}

// DFA from NFA (subset construction)
extension NFA {
    var dfa: DFA<Output> {
        
        // precompute and cache epsilon closures
        let epsilonClosures = self.epsilonClosures
        
        func epsilonClosure(from states: Set<Int>) -> Set<Int> {
            var all = Set<Int>()
            for v in states {
                all.formUnion(epsilonClosures[v])
            }
            return all
        }

        let alphabet = self.alphabet
        let q0 = epsilonClosures[self.initial]
        var Q: [Set<Int>] = [q0]
        var worklist = [(0, q0)]
        var edges: [DFA<Output>.Transition: Int] = [:]
        var accepting: [Int: Output] = [:]
        while let (qpos, q) = worklist.popLast() {
            for scalar in alphabet {
                let t = epsilonClosure(from: reachable(from: q, via: scalar))
                if t.isEmpty { continue }
                let position = Q.index(of: t) ?? Q.count
                if position == Q.count {
                    Q.append(t)
                    worklist.append((position, t))
                    if let value = t.compactMap({ self.accepting[$0] }).first {
                        accepting[Q.count - 1] = value
                    }
                }
                edges[DFA<Output>.Transition(from: qpos, scalar: scalar)] = position
            }
        }
        
        return DFA(
            states: Q.count,
            transitions: edges,
            initial: 0, // this is always zero since q0 is always the first item in Q
            accepting: accepting,
            nonAcceptingValue: self.nonAcceptingValue
        )
    }
}

// Initialize NFA from RE
extension NFA {
    init(re: RegularExpression, acceptingValue: Output, nonAcceptingValue: Output) {
        switch re {
        case .scalarClass(let scalarClass):
             self.init(
                states: 2,
                transitions: [scalarClass: [(0, 1)]],
                epsilonTransitions: [:],
                initial: 0,
                accepting: [1: acceptingValue],
                nonAcceptingValue: nonAcceptingValue
            )

        
        case .concatenation(let re1, let re2):
            let nfa1 = NFA(re: re1, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            let nfa2 = NFA(re: re2, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            
            // nfa1 followed by nfa2 with episilon transition between them
            let nfa2offset = nfa2.offset(by: nfa1.states)
            let transitions = nfa1.transitions
                .merging(nfa2offset.transitions, uniquingKeysWith: { $0 + $1 })
            let epsilonTransitions = nfa1.epsilonTransitions
                .merging(nfa2offset.epsilonTransitions, uniquingKeysWith: { $0 + $1 })
                .merging(
                    nfa1.accepting.keys.map { ($0, [nfa2offset.initial]) },
                    uniquingKeysWith: { $0 + $1 })

            self.init(
                states: nfa2offset.states,
                transitions: transitions,
                epsilonTransitions: epsilonTransitions,
                initial: nfa1.initial,
                accepting: nfa2offset.accepting,
                nonAcceptingValue: nonAcceptingValue
            )


        case .alternation(let re1, let re2):
            let nfa1 = NFA(re: re1, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            let nfa2 = NFA(re: re2, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            
            // create a common initial state that points to each nfa's initial
            // with an epsilon edge and a combined accepting dictionary
            let nfa1offset = nfa1.offset(by: 1)
            let nfa2offset = nfa2.offset(by: nfa1.states + 1)
            
            let states = nfa2offset.states
            let initial = 0
            
            let transitions = nfa1offset.transitions
                .merging(nfa2offset.transitions, uniquingKeysWith: { $0 + $1 })
            
            let epsilonTransitions = nfa1offset.epsilonTransitions
                .merging(nfa2offset.epsilonTransitions, uniquingKeysWith: { $0 + $1 })
                .merging([(0, [nfa1offset.initial, nfa2offset.initial])], uniquingKeysWith: { $0 + $1 })
            
            let accepting = nfa1offset.accepting.merging(nfa2offset.accepting, uniquingKeysWith: { first, _ in first })
            
            self.init(
                states: states,
                transitions: transitions,
                epsilonTransitions: epsilonTransitions,
                initial: initial,
                accepting: accepting,
                nonAcceptingValue: nonAcceptingValue
            )


        case .closure(let re):
            let nfa = NFA(re: re, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            
            // turn nfa into a closure by:
            // - make intial state accepting, to allow skipping the NFA (zero occurences)
            // - looping over NFA many times by connecting NFAs accepting states to its initial state
            let accepting = nfa.accepting.merging([nfa.initial: acceptingValue], uniquingKeysWith: { first, _ in first })
            let epsilonTransitions = nfa.epsilonTransitions
                .merging(
                    nfa.accepting.keys.map { ($0, [nfa.initial]) }, uniquingKeysWith: { $0 + $1 })
            
            self.init(
                states: nfa.states,
                transitions: nfa.transitions,
                epsilonTransitions: epsilonTransitions,
                initial: nfa.initial,
                accepting: accepting,
                nonAcceptingValue: nonAcceptingValue
            )
        }
    }
}
