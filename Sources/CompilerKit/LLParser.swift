struct LLParser<T: Hashable> {
    let grammar: Grammar<T>
    let nullable: [Set<Int>]
    let first: [[T: Set<Int>]]
    let follow: [Set<T>]
    let table: [[T: Int]]
    let goal: Int
    
    init(_ g: Grammar<T>, _ goal: Int) {
        var g = g
        
        // get the grammar ready for LL parsing
        g.eliminateLeftRecursion()
        g.leftRefactor()
        
        nullable = g.nullable()
        first = g.first(nullable: nullable)
        follow = g.follow(nullable: nullable, first: first)
        
        let isBacktrackFree = g.isBacktrackFree(nullable: nullable, first: first, follow: follow)
        precondition(isBacktrackFree,
                     "Cannot initialize an LL parser for a non-backtrack free grammar")
        
        var table: [[T: Int]] = Array(repeating: [:], count: g.productions.count)
        
        for nt in 0..<g.productions.count {
            first[nt].forEach { t, prods in
                table[nt][t] = prods.first!
            }
            
            if let emptyProduction = nullable[nt].first {
                for t in follow[nt] {
                    table[nt][t] = emptyProduction
                }
            }
        }
        
        self.grammar = g
        self.table = table
        self.goal = goal
    }
    
    
    func parse(_ words: [T]) -> Bool {
        var current = 0
        
        func advance() { current += 1 }
        
        func peek() -> T? {
            guard current < words.count else { return nil }
            return words[current]
        }
        
        var stack: [Grammar<T>.Node<T>] = [.nt(goal)]
        
        while let focus = stack.popLast() {
            guard let word = peek() else {
                // unexpected end of input
                return false
            }
            switch focus {
            case let .t(t):
                guard t == word else {
                    // unexpected word
                    return false
                }
                advance()
                
            case let .nt(nt):
                guard let p = table[nt][word] else {
                    // unexpected word
                    return false
                }
                
                stack.append(contentsOf: grammar.productions[nt][p].reversed())
            }
        }
        
        if peek() != nil {
            // input contains unconsumed words at the end
            return false
        }
        
        return true
    }
}
