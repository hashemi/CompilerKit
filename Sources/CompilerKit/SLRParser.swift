extension LRParser {
    init(slr g: Grammar<T>) {
        let grammar = g.augmented
        
        // construct the LR(0) state machine
        let nullable = grammar.nullable()
        let first = grammar.first(nullable: nullable)
        let follow = grammar.follow(nullable: nullable, first: first)
        
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
                accepting[items.count - 1] = .reduce(s, prods[s][p].count, follow[s])
            }
        }
        
        // add a final accepting state
        let initial = nonterminalProductionStartingItems[grammar.start][0]
        let finalAccepting = items.count
        transitions[.nt(grammar.start)] = [(initial, finalAccepting)]
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
}
