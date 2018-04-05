struct Grammar<T: Hashable> {
    enum Node<T: Hashable>: Hashable {
        case nt(Int)
        case t(T)
    }
    
    var productions: [[[Node<T>]]]
    
    mutating func eliminateLeftRecursion() {
        for i in 0..<productions.count {
            if i > 0 {
                // find productions starting with a preceeding NT
                // as they could lead to indirect left recursion
                for j in 0..<i {
                    for p in 0..<productions[i].count {
                        if productions[i][p].first == .nt(j) {
                            // replace the potentially problematic first NT
                            // with all of its possible productions
                            let tail = productions[i][p][1...]
                            productions[i][p] = productions[j].first! + tail
                            for sub in productions[j][1...] {
                                productions[i].append(sub + tail)
                            }
                        }
                    }
                }
            }
            
            // eliminate direct left recursion
            if productions[i].contains(where: { $0.first == .nt(i) }) {
                let newNt = productions.count
                productions.append([[]])
                let current = productions[i]
                productions[i] = []
                for p in current {
                    if p.first == .nt(i) {
                        productions[newNt].append(p[1...] + [.nt(newNt)])
                    } else {
                        productions[i].append(p + [.nt(newNt)])
                    }
                }
            }
        }
    }
    
    mutating func leftRefactor() {
        while true {
            let lastProductions = productions
            for s in 0..<productions.count {
                for i in 0..<productions[s].count where !productions[s][i].isEmpty {
                    var prefixLength = 1
                    var matchingProductions = [i]
                    while true {
                        if prefixLength == productions[s][i].count { break }
                        let lastProductions = matchingProductions
                        matchingProductions = [i]
                        for j in 0..<productions[s].count where i != j && productions[s][j].starts(with: productions[s][i].prefix(upTo: prefixLength)) {
                                matchingProductions.append(j)
                        }
                        
                        // had more matches before this iteration, undo the iteration and stop
                        if matchingProductions.count < lastProductions.count {
                            prefixLength -= 1
                            matchingProductions = lastProductions
                            break
                        }
                        
                        // can't find matches with this prefix, no point trying a longer prefix
                        if matchingProductions.count == 1 { break }
                        
                        prefixLength += 1
                    }
                    
                    if matchingProductions.count > 1 {
                        // save common prefix
                        let commonPrefix = productions[s][matchingProductions.first!].prefix(upTo: prefixLength)
                        
                        // save matching productions with their common prefix removed
                        let matchingProductionsWithoutCommonPrefix = matchingProductions.map {
                            Array(productions[s][$0][prefixLength...])
                        }
                        
                        // create a new NT for the common factor
                        let newNt = productions.count
                        productions.append(matchingProductionsWithoutCommonPrefix)
                        
                        productions[s] = productions[s]
                            .enumerated()
                            .filter { !matchingProductions.contains($0.offset) }
                            .map { $0.element }
                            + [commonPrefix + [.nt(newNt)]]
                        
                        break
                    }
                }
            }
            if productions == lastProductions { break }
        }
    }
    
    func nullable() -> [Set<Int>] {
        var nullable: [Set<Int>] = Array(repeating: Set<Int>(), count: productions.count)
        
        func nodeIsNullabe(_ n: Node<T>) -> Bool {
            switch n {
            case .t(_): return false
            case let .nt(nt): return !nullable[nt].isEmpty
            }
        }
        
        while true {
            let lastValue = nullable
            for s in 0..<productions.count {
                for (pIdx, p) in productions[s].enumerated() {
                    // production is nullable iff all of its nodes are nullable (or production is empty)
                    let isNullable = { () -> Bool in
                        for node in p where !nodeIsNullabe(node) {
                            return false
                        }
                        return true
                    }()
                    
                    if isNullable {
                        nullable[s].insert(pIdx)
                    }
                }
            }
            if nullable == lastValue { break }
        }
        
        return nullable
    }
    
    func first(nullable: [Set<Int>]) -> [[T: Set<Int>]] {
        precondition(nullable.count == productions.count)
        var first: [[T: Set<Int>]] = Array(repeating: [:], count: productions.count)
        
        func firstByNode(_ n: Node<T>) -> Set<T> {
            switch n {
            case let .t(t): return Set([t])
            case let .nt(nt): return Set(first[nt].keys)
            }
        }
        
        while true {
            let lastValue = first
            for s in 0..<productions.count {
                for (pIdx, p) in productions[s].enumerated() {
                    if p.isEmpty { continue }
                    
                    var rhs: Set<T> = firstByNode(p.first!)
                    
                    for node in p {
                        if case let .nt(nt) = node, !nullable[nt].isEmpty {
                            // accumulate first sets of nonterminal nodes with nullable productions...
                            rhs.formUnion(firstByNode(node))
                        } else {
                            // ...until we hit the first terminal or non-nullable
                            break
                        }
                    }
                    
                    for t in rhs {
                        first[s][t, default: []].insert(pIdx)
                    }
                }
            }
            if first == lastValue { break }
        }
        
        return first
    }
    
    func follow(nullable: [Set<Int>], first: [[T: Set<Int>]]) -> [Set<T>] {
        precondition(nullable.count == productions.count)
        precondition(first.count == productions.count)
        var follow = Array(repeating: Set<T>(), count: productions.count)
        
        while true {
            let lastValue = follow
            for s in 0..<productions.count {
                for p in productions[s] {
                    var trailer = follow[s]
                    if p.isEmpty { continue }
                    for n in p.reversed() {
                        switch n {
                        case let .nt(nt):
                            follow[nt].formUnion(trailer)
                            
                            if !nullable[nt].isEmpty {
                                trailer.formUnion(first[nt].keys)
                            } else {
                                trailer = Set(first[nt].keys)
                            }
                        case let .t(t): trailer = [t]
                        }
                    }
                }
            }
            if lastValue == follow { break }
        }
        
        return follow
    }
    
    func isBacktrackFree(nullable: [Set<Int>], first: [[T: Set<Int>]], follow: [Set<T>]) -> Bool {
        precondition(nullable.count == productions.count)
        precondition(first.count == productions.count)
        precondition(follow.count == productions.count)
        
        for s in 0..<productions.count {
            // make sure no term leads to more than 1 production
            if first[s].values.contains(where: { $0.count > 1 }) {
                return false
            }
            
            // we can only have production that can be empty
            if nullable[s].count > 1 { return false }
            
            // if we do have one empty production, we need to make sure that
            // non of the terminals that can follow this term is also part of
            // the first set of one of its productions
            if nullable[s].count == 1 {
                if !follow[s].isDisjoint(with: first[s].keys) {
                    return false
                }
            }
        }
        
        return true
    }
}
