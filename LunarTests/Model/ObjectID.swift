import Foundation


public typealias Byte = UInt8

func toByteArray<T>(_ value: T) -> [Byte] {
    var localValue: T = value
    let valueSize = MemoryLayout<T>.size
    
    return withUnsafePointer(to: &localValue) { localPointer in
        localPointer.withMemoryRebound(to: UInt8.self, capacity: valueSize) {
            Array(UnsafeBufferPointer(start: $0, count: valueSize))
        }
    }
}

extension Sequence where Iterator.Element == Byte {
    func toString() -> String {
        return self
            .map { String(format: "%02x", $0) }
            .reduce("", +)
    }
}

public struct ObjectID {
    public let bytes: [Byte]
    
    public init(bytes: [Byte]) {
        self.bytes = bytes
    }
    
    public init(string: String) {
        let characters = Array(string.characters)
        let byteStrings = stride(from: 0, to: characters.count, by: 2)
            .map { index in
                return String(characters[index..<min(index+2, characters.count)])
        }
        
        self.init(bytes: byteStrings.map { UInt8(strtoul($0, nil, 16)) })
    }
}

extension ObjectID: Hashable {
    public var hashValue: Int {
        return toString().hashValue
    }
}

extension ObjectID: Equatable { }
public func == (lhs: ObjectID, rhs: ObjectID) -> Bool {
    return lhs.toString() == rhs.toString()
}

extension ObjectID: CustomStringConvertible, CustomDebugStringConvertible {
    public var description: String {
        return toString()
    }
    
    public var debugDescription: String {
        return "ObjectID(\(description))"
    }
    
    public func toString() -> String {
        return bytes.toString()
    }
    
    public func toTimestamp() -> TimeInterval {
        let hexString = toString()
        let timestampHexString = hexString.substring(to: hexString.characters.index(hexString.startIndex, offsetBy: (2 * TimestampByteSize)))
        
        guard let timestamp = UInt(timestampHexString, radix: 16)
            else {
                fatalError("Could not decode timestamp")
        }
        
        return TimeInterval(timestamp)
    }
    
    public func toDate() -> Date {
        return Date(timeIntervalSince1970: toTimestamp())
    }
}

private let TimestampByteSize = 4
private let ProcessIDByteSize = 2
private let CounterByteSize = 3

extension ObjectID {
    public static var generator = Generator()
    
    public struct Generator {
        fileprivate var count: Int32
        fileprivate let processID: [Byte]
        fileprivate let machineID: [Byte]
        
        init() {
            self.count = Int32.random().bigEndian
            
            /// Pull the first 3 bytes of a random UUID for the machine ID
            let uuid = UUID().uuid
            self.machineID = [uuid.0, uuid.1, uuid.2]
            
            /// Get the process identifier from the `ProcessInfo` and grab the first 2 bytes
            let processIDByteArray = toByteArray(ProcessInfo.processInfo.processIdentifier)
            self.processID = Array(processIDByteArray[0..<ProcessIDByteSize])
        }
        
        mutating public func next() -> ObjectID {
            let count: [Byte] = Array(toByteArray(self.count)[0..<CounterByteSize])
            let bytes: [Byte] = nextTimestamp() + self.machineID + self.processID + count
            
            if self.count + 1 > Int32.max {
                self.count = Int32.random().bigEndian
            } else {
                self.count += 1
            }
            
            return ObjectID(bytes: bytes)
        }
        
        fileprivate func nextTimestamp() -> [Byte] {
            let epochTimestamp: UInt = UInt(Date().timeIntervalSince1970).bigEndian
            let timestampByteArray: [Byte] = toByteArray(epochTimestamp)
            let rangeEnd = timestampByteArray.count
            let rangeStart = rangeEnd - TimestampByteSize
            
            return Array(timestampByteArray[rangeStart..<rangeEnd])
        }
    }
}

public extension Int32 {
    public static func random(lower: Int32 = min, upper: Int32 = max) -> Int32 {
        let r = arc4random_uniform(UInt32(Int64(upper) - Int64(lower)))
        return Int32(Int64(r) + Int64(lower))
    }
}
