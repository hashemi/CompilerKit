extension Grammar.Node: Matcher {
    typealias Element = Grammar.Node<T>
    
    static func ~=(pattern: Element, value: Element) -> Bool {
        return pattern == value
    }
}

struct LRParser<T: Hashable> {
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
    
    enum Action: Hashable {
        case shift
        case reduce(Int, Int, Set<T>)
        case accept
        case error
    }
    
    let dfa: DFA<Set<LRParser.Action>, Node>
    
    func parse<S: Sequence>(_ elements: S) -> Bool where S.Element == T {
        var stack: [Node] = []
        var it = elements.makeIterator()
        
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
            case let .reduce(nt, size, _):
                stack.removeLast(size)
                stack.append(.nt(nt))
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
                    if case let .reduce(_, _, la) = action {
                        if let lookahead = lookahead {
                            return la.contains(lookahead)
                        }
                        return true
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
