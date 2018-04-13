private extension Grammar {
    subscript(_ item: LALRParser<T>.Item) -> Node<T>? {
        let prod = productions[item.term][item.production]
        guard item.position < prod.count else { return nil }
        return prod[item.position]
    }
}

struct LALRParser<T: Hashable> {
    typealias Node = Grammar<T>.Node<T>
    
    struct Item: Hashable {
        let term: Int
        let production: Int
        let position: Int
        
        var next: Item {
            return Item(term: term, production: production, position: position + 1)
        }
    }
    
    // (p, A) where p is state and A is nt
    struct Transition: Hashable {
        let state: Set<Item>
        let nt: Int
    }
    
    let grammar: Grammar<T>
    let nullable: [Set<Int>]
    
    var startItem: Item {
        return Item(term: grammar.productions.count - 1, production: 0, position: 0)
    }
    
    let allNodes: Set<Node>
    
    init(_ g: Grammar<T>) {
        grammar = g.augmented
        self.nullable = grammar.nullable()
        self.allNodes = Set(grammar.productions.flatMap { $0.flatMap { $0 } })
    }
    
    func closure(_ I: Set<Item>) -> Set<Item> {
        var J = I
        var lastCount: Int
        repeat {
            lastCount = J.count
            for j in J {
                if let node = grammar[j] {
                    if case let .nt(nt) = node {
                        for x in 0..<grammar.productions[nt].count {
                            J.insert(Item(term: nt, production: x, position: 0))
                        }
                    }
                }
            }
        } while J.count != lastCount
        return J
    }
    
    func goto(_ I: Set<Item>, _ X: Node) -> Set<Item> {
        var G: Set<Item> = []
        for i in I {
            if let node = grammar[i], node == X {
                G.insert(i.next)
            }
        }
        
        return closure(G)
    }
    
    func goto(_ t: Transition) -> Set<Item> {
        return goto(t.state, .nt(t.nt))
    }
    
    func itemSets() -> Set<Set<Item>> {
        var C: Set<Set<Item>> = [closure([startItem])]
        
        var lastCount = 0
        while lastCount != C.count {
            lastCount = C.count
            for I in C {
                for x in allNodes {
                    let g = goto(I, x)
                    if !g.isEmpty { C.insert(g) }
                }
            }
        }
        
        return C
    }
    
    func allTransitions(_ itemSets: Set<Set<Item>>) -> Set<Transition> {
        var transitions: Set<Transition> = []
        
        for itemSet in itemSets {
            for i in itemSet {
                if case let .nt(nt)? = grammar[i] {
                    transitions.insert(Transition(state: itemSet, nt: nt))
                }
            }
        }
        
        return transitions
    }
    
    func directRead(_ t: Transition) -> Set<T> {
        var terminals: Set<T> = []
        
        let G = goto(t)
        for i in G {
            if case let .t(terminal)? = grammar[i] {
                terminals.insert(terminal)
            }
        }
        
        return terminals
    }
    
    func reads(_ t: Transition) -> Set<Transition> {
        var relations: Set<Transition> = []
        
        let g = goto(t.state, .nt(t.nt))
        for i in g {
            guard case let .nt(nt)? = grammar[i.next] else { continue }
            
            if !nullable[nt].isEmpty {
                relations.insert(Transition(state: g, nt: nt))
            }
        }
        
        return relations
    }

    // 't' is (p, A) in DeRemer & Pennello's description of includes
    func includes(_ t: Transition, _ allTransitions: Set<Transition>) -> Set<Transition> {
        var includes: Set<Transition> = []
        
        func tailNullable(_ i: Item) -> Bool {
            let prod = grammar.productions[i.term][i.production]
            
            // if item is last in a production, the tail is empty
            // and therefore is nullable
            guard i.position < prod.count else { return true }
            
            let nodes = prod[i.position..<prod.count]
            
            for n in nodes {
                switch n {
                case .t(_): return false
                case let .nt(nt): if !nullable[nt].isEmpty { return false }
                }
            }
            return true
        }
        
        // check every other transtion for being in t's includes
        // 'pre' is (p', B) in DeRemer & Pennello's description of includes
        for pre in allTransitions {
            // find items that reduce to B as candidates for [B -> β A ɣ]
            for initialItem in pre.state where initialItem.term == pre.nt {
                // check all possible (q, C) transitions we can take from this item
                // is our 't' one of them?
                var item = initialItem
                var q = pre.state
                while let node = grammar[item] {
                    if case let .nt(nt) = node {
                        if Transition(state: q, nt: nt) == t {
                            // we just got to (p, A) from 'pre'
                            // this means that this item is [B -> β .A ɣ]
                            // if ɣ is nullable, the (p, A) includes (p', B)
                            // i.e., 't' includes 'pre'
                            if tailNullable(item.next) {
                                includes.insert(pre)
                            }
                        }
                    }
                    
                    q = goto(q, node)
                    item = item.next
                }
                
            }
        }
        
        return includes
    }
    
    func digraph<Input: Hashable, Output: Hashable>(
        _ input: Set<Input>,
        _ relation: @escaping (Input) -> (Set<Input>),
        _ fp: @escaping (Input) -> (Set<Output>)) -> [Input: Set<Output>] {
        
        var stack: [Input] = []
        var result: [Input: Set<Output>] = [:]
        var n = Dictionary(uniqueKeysWithValues: input.map { ($0, 0) })
        
        func traverse(_ x: Input) {
            stack.append(x)
            let d = stack.count
            n[x] = d
            result[x] = fp(x)
            for y in relation(x) {
                if n[y] == 0 { traverse(y) }
                n[x] = min(n[x]!, n[y]!)
                result[x]!.formUnion(result[y]!)
            }
            if n[x] == d {
                repeat {
                    n[stack.last!] = Int.max
                    result[stack.last!] = result[x]
                } while stack.popLast() != x
            }
        }
        
        for x in input where n[x] == 0 {
            traverse(x)
        }
        
        return result
    }
}
