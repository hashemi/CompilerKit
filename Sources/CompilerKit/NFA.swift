import Bitset

struct NFA<T> {
    struct Edge: Hashable {
        let from: Int
        let scalar: UnicodeScalar
    }
    
    let vertices: Int
    let edges: [Edge: [Int]]
    let epsilonTransitions: [Int: [Int]]
    let initial: Int
    let accepting: [Int: T]
    let nonAcceptingValue: T
    
    var alphabet: Set<UnicodeScalar> {
        return edges.keys.reduce(into: Set<UnicodeScalar>(), { set, edge in
            set.insert(edge.scalar)
        })
    }
    
    func epsilonClosure(from states: Bitset) -> Bitset {
        var marked = Bitset()
        
        func dfs(_ s: Int) {
            marked.add(s)
            for w in epsilonTransitions[s, default: []] {
                if !marked.contains(w) { dfs(w) }
            }
        }
        
        for s in states {
            if !marked.contains(s) { dfs(s) }
        }
        
        return marked
    }
    
    func reachable(from states: Bitset, via scalar: UnicodeScalar) -> Bitset {
        let bitset = Bitset()
        states.forEach {
            edges[Edge(from: $0, scalar: scalar), default: []].forEach {
                bitset.add($0)
            }
        }
        return bitset
    }
    
    func match(_ s: String) -> T {
        var states = Bitset(initial)
        for scalar in s.unicodeScalars {
            // add all states reachable by epsilon transitions
            states = epsilonClosure(from: states)
            
            // new set of states as allowed by current scalar in string
            states = reachable(from: states, via: scalar)
        }
        return states.compactMap { self.accepting[$0] }.first ?? nonAcceptingValue
    }
    
    func offset(by offset: Int) -> NFA {
        return NFA(
            vertices: vertices + offset,
            edges: Dictionary(uniqueKeysWithValues: edges.map { (Edge(from: $0.key.from + offset, scalar: $0.key.scalar), $0.value.map { $0 + offset } ) }),
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
        var edges: [Edge: [Int]] = [:]
        var epsilonTransitions: [Int: [Int]] = [:]
        var accepting: [Int: T] = [:]
        
        for nfa in alternatives {
            let offset = nfa.offset(by: vertices)
            edges.merge(offset.edges, uniquingKeysWith: { first, _ in first })
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
        let alphabet = self.alphabet
        let q0 = epsilonClosure(from: [self.initial])
        var Q: [Bitset] = [q0]
        var worklist = [q0]
        var T: [(from: Bitset, to: Bitset, scalar: UnicodeScalar)] = []
        while let q = worklist.popLast() {
            for scalar in alphabet {
                let t = epsilonClosure(from: reachable(from: q, via: scalar))
                if t.isEmpty() { continue }
                T.append((from: q, to: t, scalar: scalar))
                if !Q.contains(t) {
                    Q.append(t)
                    worklist.append(t)
                }
            }
        }
        
        // create a dictionary that maps sets to their positions in Q
        let qPositions = Dictionary<Bitset, Int>(uniqueKeysWithValues: Q.enumerated().map { ($0.element, $0.offset) })

        let vertices = Q.count
        
        let edges = Dictionary(uniqueKeysWithValues: T.map { t in
            (DFA<T>.Edge(from: qPositions[t.from]!, scalar: t.scalar), qPositions[t.to]!)
        })
        
        let initial = 0 // this is always zero since we always add q0 first to Q
        let accepting = Dictionary(uniqueKeysWithValues: Q.enumerated().compactMap { (i, q) -> (Int, T)? in
            if let value = q.compactMap({ self.accepting[$0] }).first {
                return (i, value)
            } else {
                return nil
            }
        })
        
        return DFA(vertices: vertices, edges: edges, initial: initial, accepting: accepting, nonAcceptingValue: self.nonAcceptingValue)
    }
}

// Initialize NFA from RE
extension NFA {
    init(re: RegularExpression, acceptingValue: T, nonAcceptingValue: T) {
        switch re {
        case .scalar(let scalar):
             self.init(
                vertices: 2,
                edges: [Edge(from: 0, scalar: scalar): [1]],
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
