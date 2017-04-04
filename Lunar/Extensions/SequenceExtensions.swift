import Foundation

extension Sequence {
    func index<Key: Hashable>(by key: (Iterator.Element) -> Key?) -> [Key: [Iterator.Element]] {
        return index(by: { (element) -> (Key, Iterator.Element)? in
            guard let _key = key(element) else { return nil }
            return (_key, element)
        })
    }
    
    func index<Key, Value>(by map: (Iterator.Element) -> (Key, Value)?) -> [Key: [Value]] {
        var index: [Key: [Value]] = [:]
        
        for element in self {
            guard let (key, value) = map(element) else { continue }
            
            if index[key] == nil {
                index[key] = []
            }
            
            index[key]?.append(value)
        }
        
        return index
    }
}
