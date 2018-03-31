struct Grammar<T: Hashable> {
    enum Node<T: Hashable>: Hashable {
        case nt(Int)
        case t(T)
    }
    
    var productions: [[[Node<T>]]]
    let rootTerm: Int
    let eof: T
    
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
    
    var first: ([[T: Set<Int>]], [Set<Int>]) {
        var first: [[T: Set<Int>]] = Array(repeating: [:], count: productions.count)
        var canBeEmpty = Array(repeating: Set<Int>(), count: productions.count)
        
        func firstByNode(_ n: Node<T>) -> Set<T> {
            switch n {
            case let .t(t): return Set([t])
            case let .nt(nt): return Set(first[nt].keys)
            }
        }
        
        func canBeEmptyByNode(_ n: Node<T>) -> Bool {
            switch n {
            case .t(_): return false
            case let .nt(nt): return !canBeEmpty[nt].isEmpty
            }
        }
        
        while true {
            let beforeIteration = (first, canBeEmpty)
            for s in 0..<productions.count {
                for (pIdx, p) in productions[s].enumerated() {
                    guard !p.isEmpty else {
                        canBeEmpty[s].insert(pIdx)
                        continue
                    }
                    
                    var rhs: Set<T> = firstByNode(p.first!)
                    var i = 0
                    while canBeEmptyByNode(p[i]) && i < p.count - 1 {
                        rhs.formUnion(firstByNode(p[i]))
                        i += 1
                    }
                    
                    if i == p.count - 1 && canBeEmptyByNode(p[i]) {
                        canBeEmpty[s].insert(pIdx)
                    }
                    
                    for t in rhs {
                        first[s][t, default: []].insert(pIdx)
                    }
                }
            }
            if (first, canBeEmpty) == beforeIteration { break }
        }
        
        return (first, canBeEmpty)
    }
    
    var follow: [Set<T>] {
        var (first, canBeEmpty) = self.first
        var follow = Array(repeating: Set<T>(), count: productions.count)
        follow[rootTerm].insert(eof)
        
        while true {
            let beforeIteration = follow
            for s in 0..<productions.count {
                for p in productions[s] {
                    var trailer = follow[s]
                    if p.isEmpty { continue }
                    for n in p.reversed() {
                        switch n {
                        case let .nt(nt):
                            follow[nt].formUnion(trailer)
                            
                            if !canBeEmpty[nt].isEmpty {
                                trailer.formUnion(first[nt].keys)
                            } else {
                                trailer = Set(first[nt].keys)
                            }
                        case let .t(t): trailer = [t]
                        }
                    }
                }
            }
            if beforeIteration == follow { break }
        }
        
        return follow
    }
    
    var isBacktrackFree: Bool {
        let (first, canBeEmpty) = self.first
        let follow = self.follow
        for s in 0..<productions.count {
            // make sure no term leads to more than 1 production
            if first[s].values.contains(where: { $0.count > 1 }) {
                return false
            }
            
            // we can only have production that can be empty
            if canBeEmpty[s].count > 1 { return false }
            
            // if we do have one empty production, we need to make sure that
            // non of the terminals that can follow this term is also part of
            // the first set of one of its productions
            if canBeEmpty[s].count == 1 {
                if !follow[s].isDisjoint(with: first[s].keys) {
                    return false
                }
            }
        }
        
        return true
    }
}

