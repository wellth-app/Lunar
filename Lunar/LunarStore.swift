import Apollo
import CoreData
import JSONMapping
import RemoteMapping


struct LunarStore: NormalizedCache {
    private let managedObjectContext: NSManagedObjectContext
    private let dateFormatter: JSONDateFormatter?
    
    init(context: NSManagedObjectContext, dateFormatter: JSONDateFormatter? = nil) {
        self.managedObjectContext = context
        self.dateFormatter = dateFormatter
    }
    
    func loadRecords(forKeys keys: [CacheKey]) -> Promise<[Record?]> {
        let context = managedObjectContext
        let formatter = dateFormatter
        
        return Promise { success, error in
            let records = keys
                .flatMap { key -> (type: String, id: String)? in
                    return GraphQLID.decode(id: key)
                }
                .reduce([Record]()) { records, meta in
                    guard let entityDescription = NSEntityDescription.entity(forEntityName: meta.type, in: context)
                    else { return records }
                    
                    /// Create a fetch request for the object
                    let fetchRequest = NSFetchRequest<NSManagedObject>(entityName: meta.type)
                    fetchRequest.predicate = entityDescription.matchingLocalPrimaryKey(keyValue: meta.id)
                    
                    do {
                        let result = try context.fetch(fetchRequest)
                        return records + result
                            .flatMap { object -> Record? in
                                guard let primaryKey = object.primaryKey as? String
                                else {
                                    return nil
                                }
                                
                                let relationshipType: RelationshipType = .custom({ object in
                                    guard let primaryKey = object.primaryKey as? String
                                    else {
                                        return NSNull()
                                    }
                                    
                                    return Reference(key: primaryKey)
                                })
                                
                                let json = object.toJSON(
                                    relationshipType: relationshipType,
                                    dateFormatter: formatter
                                )
                                
                                return Record(key: primaryKey, json)
                            }
                    } catch {
                        return records
                    }
                }
            
            success(records)
        }
    }
    
    func merge(records: RecordSet) -> Promise<Set<CacheKey>> {
        let context = managedObjectContext
        let formatter = dateFormatter
        
        return Promise { success, error in
            let keys: [CacheKey] = records.storage
                .index(by: { (key, value) -> (String, (String, Record)) in
                    let (type, id) = GraphQLID.decode(id: key)!
                    return (type, (id, value))
                })
                .flatMap { (entityName, value) -> [CacheKey]? in
                    guard let entityDescription = NSEntityDescription.entity(forEntityName: entityName, in: context)
                    else { return nil }
                    
                    let dictionary = Dictionary(value)
                    let localPrimaryKeys = Set(dictionary.keys)
                    
                    let (updates, inserts) = context.detectChanges(
                        inEntity: entityName,
                        primaryKeyCollection: localPrimaryKeys,
                        localPrimaryKeyName: entityDescription.localPrimaryKeyName
                    )
                    
                    var cacheKeys: [CacheKey] = updates
                        .flatMap { object in
                            guard let localPrimaryKey = object.primaryKey as? String,
                                let record = dictionary[localPrimaryKey]
                            else { return nil }
                            
                            object.merge(
                                withJSON: record.fields,
                                dateFormatter: formatter
                            )
                            
                            return localPrimaryKey
                        }
                    
                    cacheKeys += inserts
                        .flatMap { objectID -> (String, JSONObject)? in
                            guard let initialData = dictionary[objectID]
                            else { return nil }
                            return (objectID, initialData.fields)
                        }
                        .map { (id, data) -> CacheKey in
                            context.upsert(
                                json: data,
                                inEntity: entityDescription,
                                withPrimaryKey: id
                            )
                            
                            return id
                        }
            
                    return cacheKeys
                }
                .reduce([CacheKey](), +)

            success(Set(keys))
        }
    }
}
