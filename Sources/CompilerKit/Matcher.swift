protocol Matcher {
    associatedtype Element
    
    static func ~=(pattern: Self, value: Element) -> Bool
}
