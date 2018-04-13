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
}
