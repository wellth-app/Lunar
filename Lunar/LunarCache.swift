import Apollo
import CoreData


/// String references
private enum Key: String  {
    case reference = "reference"
    case record = "record"
    case key = "key"
    case modelName = "Lunar"
    case entityName = "LunarRecord"
}

/// Converts the CacheKey used by Apollo to a CacheKey used by the CoreData
/// schema.
private func recordCacheKey(forFieldCacheKey cacheKey: CacheKey) -> CacheKey {
    var components = cacheKey.components(separatedBy: ".")
    if components.count > 1 {
        components.removeLast()
    }
    
    return components.joined(separator: ".")
}

/// A CoreData cache for use with `ApolloStore`.
public class LunarCache: NormalizedCache {
    /// The default URL to use for disk persistence. This is used during initialization
    /// of a `LunarCache`. In order to ensure that the data is stored at the
    /// desired directory, set this variable, THEN initialize a new `LunarCache`.
    static var cacheURL: URL = URL.documentsDirectoryURL()
    
    /// Non-fatal errors that occur throughout the lifecycle of the cache.
    public enum Error: Swift.Error {
        /// Indicates that `value` is invalid.
        case invalidValue(value: JSONValue)
        /// Indicates that `json` is not encoded properly
        case invalidEncoding(json: String)
        /// Indicates that `object` is not a valid JSON shape (dictionary).
        case invalidShape(object: Any)
        /// Thrown when an error occurs while purging
        case purgeError(Swift.Error)
    }
    
    /// The persistent store coordinator for the Lunar managed object model
    let persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    /// Whether or not to exclusively use the main queue (used for testing).
    private let useMainQueueContext: Bool
    
    /// The bundle where the model exists.
    private let bundle: Bundle
    
    /// The URL for the cache.
    private let url: URL
    
    /// Initializes a new `LunarCache`.
    ///
    /// - Parameter useMainQueueContext: Indicates whether or not the cache
    ///   should use the main queue context exclusively. This defaults to false,
    ///   as it's only useful for testing. The best practice is to perform 
    ///   mutations on a background context to avoid blocking the UI thread.
    public init(cacheURL: URL = LunarCache.cacheURL, useMainQueueContext: Bool = false) throws {
        let modelBundle = Bundle(for: LunarRecord.self)
        let modelName = Key.modelName.rawValue
        
        self.url = cacheURL
        self.bundle = modelBundle
        self.useMainQueueContext = useMainQueueContext
        self.persistentStoreCoordinator = NSPersistentStoreCoordinator(
            managedObjectModel: NSManagedObjectModel(
                bundle: modelBundle,
                name: modelName
            )
        )
        
        try persistentStoreCoordinator.addPersistentSQLiteStore(
            bundle: modelBundle,
            modelName: modelName,
            url: cacheURL
        )
    }
    
    /// Loads `Record`s with matching `key` properties in `keys`.
    ///
    /// - Returns: A promise that resolves with an array of `Record?`s, or
    ///            rejects with a `LunarCache.Error`, typically indicating a
    ///            deserialization error.
    public func loadRecords(forKeys keys: [CacheKey]) -> Promise<[Record?]> {
        let context = newManagedObjectContext()
        
        return Promise<[Record?]> { resolve, reject in
            context.performAndWait {
                do {
                    let records = try self.selectRecords(forKeys: keys, inContext: context)
                    let recordsOrNil: [Record?] = keys.map { key in
                        if let index = records.index(where: { $0.key == key }) {
                            return records[index]
                        }
                        
                        return nil
                    }
                    
                    resolve(recordsOrNil)
                } catch {
                    reject(error)
                }
            }
        }
    }
    
    /// Merges `records` into the persistent store.
    ///
    /// - Returns: A Promise that resolves with a Set of CacheKeys for the 
    ///            merged Records, or rejects with a LunarCache.Error indicating
    //             a serialization error, or an NSError from attempting to save
    ///            the managed object context.
    public func merge(records: RecordSet) -> Promise<Set<CacheKey>> {
        let context = newManagedObjectContext()
        
        return Promise { resolve, reject in
            context.performAndWait {
                do {
                    let records = try self.mergeRecords(records: records, inContext: context)
                    try context.save()
                    resolve(records)
                } catch {
                    reject(error)
                }
            }
        }
    }
    
    /// Purges all records from the cache.
    ///
    /// - Throws: A `LunarCache.Error` that occurs while removing the persisted
    ///   records.
    public func purge() throws {
        let storeCoordinator = persistentStoreCoordinator
        
        var purgeError: Error? = nil
        storeCoordinator.performAndWait {
            for store in storeCoordinator.persistentStores {
                guard let storeURL = store.url else { return }
                
                do {
                    try storeCoordinator.destroyPersistentStore(
                        at: storeURL,
                        ofType: NSSQLiteStoreType,
                        options: store.options
                    )
                    
                    try storeCoordinator.addPersistentSQLiteStore(
                        bundle: self.bundle,
                        modelName: Key.modelName.rawValue,
                        url: self.url
                    )
                } catch {
                    purgeError = Error.purgeError(error)
                }
            }
        }
        
        if let error = purgeError {
            throw error
        }
    }
    
    /// Creates a new NSManagedObjectContext for fetching or mutating data from
    /// the persistent store coordinator.
    ///
    /// - Returns: A new NSManagedObjectContext with private concurrency.
    private func newManagedObjectContext() -> NSManagedObjectContext {
        let concurrencyType: NSManagedObjectContextConcurrencyType = useMainQueueContext
            ? .mainQueueConcurrencyType
            : .privateQueueConcurrencyType
        
        let context = NSManagedObjectContext(concurrencyType: concurrencyType)
        context.persistentStoreCoordinator = self.persistentStoreCoordinator
        context.undoManager = nil
        context.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy
        return context
    }
}

private extension LunarCache {
    func selectRecords(forKeys keys: [CacheKey], inContext context: NSManagedObjectContext) throws -> [Record] {
        let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: Key.entityName.rawValue)
        fetchRequest.predicate = NSPredicate(format: "%K in %@", Key.key.rawValue, keys)
        
        return try context
            .fetch(fetchRequest)
            .flatMap { object in
                guard let recordString = object.value(forKey: Key.record.rawValue) as? String,
                    let recordData = recordString.data(using: .utf8),
                    let recordKey = object.value(forKey: Key.key.rawValue) as? String
                else {
                    return nil
                }
                
                return Record(
                    key: recordKey,
                    try LunarJSONSerialization.deserialize(data: recordData)
                )
            }
    }
    
    func mergeRecords(records: RecordSet, inContext context: NSManagedObjectContext) throws -> Set<CacheKey> {
        let keys = Array<CacheKey>(records.storage.keys)
        var recordSet = RecordSet(records: try selectRecords(forKeys: keys, inContext: context))
        let changedFieldKeys = recordSet.merge(records: records)
        let changedRecordKeys = Set(changedFieldKeys.map { recordCacheKey(forFieldCacheKey: $0) })
        
        for key in changedRecordKeys {
            if let fields = recordSet[key]?.fields {
                let data = try LunarJSONSerialization.serialize(fields: fields)
                guard let recordString = String(data: data, encoding: .utf8)
                else {
                    assertionFailure("Serialization did not yield UTF-8 data")
                    continue
                }

                context.upsert(
                    entityNamed: Key.entityName.rawValue,
                    matching: NSPredicate(format: "%K == %@", Key.key.rawValue, key),
                    configure: { (object: LunarRecord) in
                        object.key = key
                        object.record = recordString
                    }
                )
            }
        }
        
        return changedFieldKeys
    }
}


struct LunarJSONSerialization {
    /// Serializes a JSONObject to Data.
    ///
    /// - Parameter fields: A JSON dictionary containing the fields to serialize.
    /// - Throws: LunarCache.Error if the object is an invalid shape or value.
    /// - Returns: JSON Data
    static func serialize(fields: JSONObject) throws -> Data {
        let object = JSONObject(fields
            .enumerated()
            .map { _, element -> (CacheKey, Any) in
                return (element.key, serialize(value: element.value))
            }
        )
        
        return try JSONSerializationFormat.serialize(value: object)
    }
    
    /// Deserializes some JSON Data to a JSONObject.
    ///
    /// - Parameter data: The data representing a JSON dictionary
    /// - Throws: LunarCache.Error if the object is an invalid shape or value.
    /// - Returns: A JSON dictionary
    static func deserialize(data: Data) throws -> JSONObject {
        let json = try JSONSerializationFormat.deserialize(data: data)
        guard let jsonObject = json as? JSONObject
        else {
            throw LunarCache.Error.invalidShape(object: json)
        }
        
        return JSONObject(try jsonObject
            .enumerated()
            .map { _, element -> (CacheKey, Any) in
                return (element.key, try deserialize(value: element.value))
            }
        )
    }
    
    /// Coerces a value from a `JSONObject` to a serialized JSON Data type.
    ///
    /// - Parameter value: The value to serialize
    /// - Returns: A serialized value.
    private static func serialize(value: Any) -> Any {
        switch value {
        case let reference as Reference:
            return [
                Key.reference.rawValue: reference.key
            ]
        case let array as NSArray:
            return array.map { serialize(value: $0) }
        case let string as NSString:
            return string as String
        case let number as NSNumber:
            return number.doubleValue
        default:
            return value
        }
    }
    
    /// Coerces a value from JSON `Data` to a deserialized type for `JSONObject`
    ///
    /// - Parameter value: The value to deserialize from it's JSON Data type
    /// - Returns: A deserialized value.
    private static func deserialize(value: Any) throws -> Any {
        switch value {
        case let dictionary as JSONObject:
            guard let reference = dictionary[Key.reference.rawValue] as? String else {
                throw LunarCache.Error.invalidValue(value: value)
            }
            
            return Reference(key: reference)
        case let array as NSArray:
            return try array.map { try deserialize(value: $0) }
        default:
            return value
        }
    }
}
