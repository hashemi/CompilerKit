struct NFA<T> {
    let vertices: Int
    let edges: [ScalarClass: [(Int, Int)]]
    let epsilonTransitions: [Int: [Int]]
    let initial: Int
    let accepting: [Int: T]
    let nonAcceptingValue: T
    
    var epsilonClosures: [Bitset] {
        var epsilonClosures: [Bitset] = []
        
        for v in 0..<vertices {
            var marked = Bitset(maxValue: vertices)
            
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
        return edges.keys
    }

    func epsilonClosure(from states: Bitset) -> Bitset {
        var marked = Bitset(maxValue: vertices)
        
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

    func reachable(from states: Bitset, via scalarClass: ScalarClass) -> Bitset {
        var bitset = Bitset(maxValue: vertices)
        for (from, to) in edges[scalarClass, default: []] {
            if states.contains(from) {
                bitset.insert(to)
            }
        }
        return bitset
    }
    
    func match(_ s: String) -> T {
        var states = Bitset(maxValue: vertices)
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
            vertices: vertices + offset,
            edges: edges.mapValues { $0.map { from, to in (from + offset, to + offset) } },
            epsilonTransitions: Dictionary(uniqueKeysWithValues: epsilonTransitions.map { ($0.key + offset, $0.value.map { $0 + offset }) }),
            initial: initial + offset,
            accepting: Dictionary(uniqueKeysWithValues: accepting.map { ($0.key + offset, $0.value) }),
            nonAcceptingValue: nonAcceptingValue
        )
    }
}

extension NFA {
    init(alternatives: [NFA<T>], nonAcceptingValue: T) {
        let commonInitial = 0
        var vertices = 1
        var edges: [ScalarClass: [(Int, Int)]] = [:]
        var epsilonTransitions: [Int: [Int]] = [:]
        var accepting: [Int: T] = [:]
        
        for nfa in alternatives {
            let offset = nfa.offset(by: vertices)
            edges.merge(offset.edges, uniquingKeysWith: { $0 + $1 })
            epsilonTransitions.merge(offset.epsilonTransitions, uniquingKeysWith: { first, _ in first })
            epsilonTransitions[commonInitial, default: []].append(offset.initial)
            accepting.merge(offset.accepting, uniquingKeysWith: { first, _ in first })
            vertices = offset.vertices
        }
        
        self.init(
            vertices: vertices,
            edges: edges,
            epsilonTransitions: epsilonTransitions,
            initial: commonInitial,
            accepting: accepting,
            nonAcceptingValue: nonAcceptingValue
        )
    }
    
    init(scanner: [(RegularExpression, T)], nonAcceptingValue: T) {
        let alternatives = scanner.map { NFA(re: $0.0, acceptingValue: $0.1, nonAcceptingValue: nonAcceptingValue) }
        self.init(alternatives: alternatives, nonAcceptingValue: nonAcceptingValue)
    }
}

// DFA from NFA (subset construction)
extension NFA {
    var dfa: DFA<T> {
        
        // precompute and cache epsilon closures
        let epsilonClosures = self.epsilonClosures
        
        func epsilonClosure(from states: Bitset) -> Bitset {
            var all = Bitset(maxValue: vertices)
            for v in states {
                all.formUnion(epsilonClosures[v])
            }
            return all
        }

        let alphabet = self.alphabet
        let q0 = epsilonClosures[self.initial]
        var Q: [Bitset] = [q0]
        var worklist = [(0, q0)]
        var edges: [DFA<T>.Edge: Int] = [:]
        var accepting: [Int: T] = [:]
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
                edges[DFA<T>.Edge(from: qpos, scalar: scalar)] = position
            }
        }
        
        return DFA(
            vertices: Q.count,
            edges: edges,
            initial: 0, // this is always zero since q0 is always the first item in Q
            accepting: accepting,
            nonAcceptingValue: self.nonAcceptingValue
        )
    }
}

// Initialize NFA from RE
extension NFA {
    init(re: RegularExpression, acceptingValue: T, nonAcceptingValue: T) {
        switch re {
        case .scalarClass(let scalarClass):
             self.init(
                vertices: 2,
                edges: [scalarClass: [(0, 1)]],
                epsilonTransitions: [:],
                initial: 0,
                accepting: [1: acceptingValue],
                nonAcceptingValue: nonAcceptingValue
            )

        
        case .concatenation(let re1, let re2):
            let nfa1 = NFA(re: re1, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            let nfa2 = NFA(re: re2, acceptingValue: acceptingValue, nonAcceptingValue: nonAcceptingValue)
            
            // nfa1 followed by nfa2 with episilon transition between them
            let nfa2offset = nfa2.offset(by: nfa1.vertices)
            let edges = nfa1.edges
                .merging(nfa2offset.edges, uniquingKeysWith: { $0 + $1 })
            let epsilonTransitions = nfa1.epsilonTransitions
                .merging(nfa2offset.epsilonTransitions, uniquingKeysWith: { $0 + $1 })
                .merging(
                    nfa1.accepting.keys.map { ($0, [nfa2offset.initial]) },
                    uniquingKeysWith: { $0 + $1 })

            self.init(
                vertices: nfa2offset.vertices,
                edges: edges,
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
            let nfa2offset = nfa2.offset(by: nfa1.vertices + 1)
            
            let vertices = nfa2offset.vertices
            let initial = 0
            
            let edges = nfa1offset.edges
                .merging(nfa2offset.edges, uniquingKeysWith: { $0 + $1 })
            
            let epsilonTransitions = nfa1offset.epsilonTransitions
                .merging(nfa2offset.epsilonTransitions, uniquingKeysWith: { $0 + $1 })
                .merging([(0, [nfa1offset.initial, nfa2offset.initial])], uniquingKeysWith: { $0 + $1 })
            
            let accepting = nfa1offset.accepting.merging(nfa2offset.accepting, uniquingKeysWith: { first, _ in first })
            
            self.init(
                vertices: vertices,
                edges: edges,
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
                vertices: nfa.vertices,
                edges: nfa.edges,
                epsilonTransitions: epsilonTransitions,
                initial: nfa.initial,
                accepting: accepting,
                nonAcceptingValue: nonAcceptingValue
            )
        }
    }
}
