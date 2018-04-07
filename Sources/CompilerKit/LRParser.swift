extension Grammar.Node: Matcher {
    typealias Element = Grammar.Node<T>
    
    static func ~=(pattern: Element, value: Element) -> Bool {
        return pattern == value
    }
}

struct LRParser<T: Hashable> {
    struct Item: Hashable {
        let term: Int
        let production: Int
        let position: Int
    }
    
    enum Action: Hashable {
        case reduce(Int, Int)
        case shift
        case accept
        case error
    }
    
    typealias Node = Grammar<T>.Node<T>
    
    let grammar: Grammar<T>
    let goal: Int
    let dfa: DFA<Set<Action>, Node>
    
    init(_ g: Grammar<T>) {
        var grammar = g
        
        // create a new goal that points to the provided goal
        self.goal = grammar.productions.count
        grammar.productions.append([[.nt(grammar.start)]])
        self.grammar = grammar
        
        // construct the LR(0) state machine
        var items: [Item] = []
        var transitions: [Node: [(Int, Int)]] = [:]
        var accepting: [Int: Action] = [:]
        
        let prods = grammar.productions
        
        var nonterminalProductionStartingItems: [[Int]] = []
        
        // add all LR(0) items with transitions through each production
        for s in 0..<prods.count {
            nonterminalProductionStartingItems.append([])
            for p in 0..<prods[s].count {
                if !prods[s][p].isEmpty {
                    // the next item will be a starting state of of the 'p' production of 's' nonterminal
                    nonterminalProductionStartingItems[s].append(items.count)
                }
                
                for pos in 0..<prods[s][p].count {
                    items.append(Item(term: s, production: p, position: pos))

                    // for each position, receiving the next node takes us to the next position in the production
                    transitions[prods[s][p][pos], default: []].append((items.count - 1, items.count))
                    
                    // for each intermediate position we land on, the action is to shift
                    accepting[items.count - 1] = .shift
                }
                
                // position *past* the index of the last node in a production indicates a production has completed
                items.append(Item(term: s, production: p, position: prods[s][p].count))
                
                // production completed means we can reduce
                accepting[items.count - 1] = .reduce(s, p)
            }
        }
        
        // add a final accepting state
        let initial = nonterminalProductionStartingItems[goal][0]
        let finalAccepting = items.count
        transitions[.nt(goal)] = [(initial, finalAccepting)]
        accepting[finalAccepting] = .accept
        
        // add epsilon transitions between each nonterminal node and its productions
        var epsilonTransitions: [Int: [Int]] = [:]
        for (state, item) in items.enumerated() where item.position < prods[item.term][item.production].count {
            if case let .nt(nt) = prods[item.term][item.production][item.position] {
                epsilonTransitions[state, default: []].append(contentsOf: nonterminalProductionStartingItems[nt])
            }
        }
        
        self.dfa = NFA(
            states: items.count + 1,
            transitions: transitions,
            epsilonTransitions: epsilonTransitions,
            initial: initial,
            accepting: accepting
        ).dfa.minimized
    }
    
    func parse<S: Sequence>(_ elements: S) -> Bool where S.Element == T {
        var stack: [Node] = []
        var it = elements.makeIterator()
        let nullable = grammar.nullable()
        let first = grammar.first(nullable: nullable)
        let follow = grammar.follow(nullable: nullable, first: first)
        
        var lookahead = it.next()
        func advance() -> T? {
            let current = lookahead
            lookahead = it.next()
            return current
        }
        
        func perform(_ action: Action) -> Bool {
            switch action {
            case .shift:
                guard let t = advance() else { return false }
                stack.append(.t(t))
            case let .reduce(s, p):
                stack.removeLast(grammar.productions[s][p].count)
                stack.append(.nt(s))
            case .accept:
                guard lookahead == nil else { return false }
            case .error:
                return false
            }
            
            return true
        }
        
        while true {
            let actions = dfa.match(stack)
            let action: Action
            
            switch actions.count {
            case 0: action = .error
            case 1: action = actions.first!
            default:
                // we have a reduce/reduce or shift/reduce conflict
                // is there any viable reduce among the possible actions?
                let viableReduce = actions.first { action in
                    if case let .reduce(s, _) = action {
                        if lookahead == nil { return true }
                        return follow[s].contains(lookahead!)
                    }
                    return false
                }
                
                if let reduce = viableReduce {
                    action = reduce
                } else if actions.contains(.shift) {
                    action = .shift
                } else {
                    action = .error
                }
            }
            
            if perform(action) {
                if action == .accept { return true }
            } else {
                return false
            }
        }
    }
}
