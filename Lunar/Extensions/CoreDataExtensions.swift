import CoreData
import Apollo


extension NSManagedObjectModel {
    convenience init(bundle: Bundle, name: String) {
        if let momdModelURL = bundle.url(forResource: name, withExtension: "momd") {
            self.init(contentsOf: momdModelURL)!
        } else if let momModelURL = bundle.url(forResource: name, withExtension: "mom") {
            self.init(contentsOf: momModelURL)!
        } else {
            self.init()
        }
    }
}


enum NSPersistentStoreCoordinatorError: Error {
    /// Thrown if an error occurs while pre-loading data.
    case preloadError(Error)
    /// Thrown if an error occurs while creating a persistent store.
    case createError(Error)
    /// Thrown if an error occurs while removing a perisstent store.
    case removeError(Error)
    /// Thrown if there is an error while considering to include the store in 
    /// backups.
    case backupExclusionError(Error)
}

extension NSPersistentStoreCoordinator {
    func addPersistentSQLiteStore(bundle: Bundle, modelName: String, url: URL, includeStoreInBackup: Bool = false) throws {
        let fileManager = FileManager.default
        let filePath = modelName + ".sqlite"
        let storeURL = LunarCache.cacheURL.appendingPathComponent(filePath)
        let storePath = storeURL.path
        
        if !fileManager.fileExists(atPath: storePath),
            let preloadPath = bundle.path(forResource: modelName, ofType: "sqlite") {
            let preloadURL = URL(fileURLWithPath: preloadPath)
            
            do {
                try fileManager.copyItem(at: preloadURL, to: storeURL)
            } catch {
                throw NSPersistentStoreCoordinatorError.preloadError(error)
            }
        }
        
        let storeOptions = [
            NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true,
        ]
        
        /// !!!: This is a pretty nasty way of trying to create a store,
        /// failing, and retrying, while handling errors for each possible
        /// misstep. There's probably a way to do this without the pyramids.
        do {
            try addPersistentStore(
                ofType: NSSQLiteStoreType,
                configurationName: nil,
                at: storeURL,
                options: storeOptions
            )
        } catch {
            do {
                try fileManager.removeItem(atPath: storePath)
                do {
                    try addPersistentStore(
                        ofType: NSSQLiteStoreType,
                        configurationName: nil,
                        at: storeURL,
                        options: storeOptions
                    )
                } catch {
                    throw NSPersistentStoreCoordinatorError.createError(error)
                }
            } catch {
                throw NSPersistentStoreCoordinatorError.removeError(error)
            }
        }
        
        if !includeStoreInBackup {
            do {
                try (storeURL as NSURL).setResourceValue(true, forKey: .isExcludedFromBackupKey)
            } catch {
                throw NSPersistentStoreCoordinatorError.backupExclusionError(error)
            }
        }
    }
}


extension NSManagedObjectContext {
    @discardableResult
    func upsert<Object: NSManagedObject>(entityNamed name: String, matching predicate: NSPredicate, configure: (Object) -> Void) -> Object {
        let fetchRequest = NSFetchRequest<Object>(entityName: name)
        fetchRequest.predicate = predicate
        fetchRequest.fetchLimit = 1
        
        var result: Object?
        do {
            result = try fetch(fetchRequest).first
        } catch { }
        
        if result == nil {
            result = NSEntityDescription.insertNewObject(forEntityName: name, into: self) as? Object
        }
        
        configure(result!)
        
        return result!
    }
    
    func fetchSingleObject<Result: NSFetchRequestResult>(fetchRequest: NSFetchRequest<Result>) -> Result? {
        fetchRequest.fetchLimit = 1
        
        do {
            return try fetch(fetchRequest).first
        } catch { }
        
        return nil
    }
}
