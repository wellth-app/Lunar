import CoreData
import Apollo


extension NSManagedObjectModel {
    /// Initializes a new model using the `name` to locate or create a new `momd`
    /// or `mom` model.
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
    /// Creates a new persistent CoreData SQLite store.
    ///
    /// - Parameter bundle: The bundle in which to check for an existing store.
    /// - Parameter modelName: The name of the model to create.
    /// - Parameter url: The location at which to create the store.
    /// - Parameter includeStoreInBackup: Whether or not to include the store in
    ///   backups.
    ///
    /// - Throws: NSPersistentCoordinatorError if an error occurs.
    func addPersistentSQLiteStore(bundle: Bundle, modelName: String, url: URL, includeStoreInBackup: Bool = false) throws {
        let fileManager = FileManager.default
        let filePath = modelName + ".sqlite"
        let storeURL = url.appendingPathComponent(filePath)
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
    /// Finds an existing object matching `predicate` or creates a new one.
    /// Passes the result to `configure` for configuration and returns the result.
    ///
    /// - Parameter entityNamed name: The entity name for Object.
    /// - Parameter matching predicate: The predicate to query against.
    /// - Parameter configure: A block which accepts an Object for configuration.
    ///
    /// - Returns Object: A newly inserted or updated object.
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
}
