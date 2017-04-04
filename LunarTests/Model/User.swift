import CoreData
import Lunar
import Apollo


final class User: NSManagedObject {
    @NSManaged
    var remoteID: String
    
    @NSManaged
    var archivedAt: Date?
    
    @NSManaged
    var updatedAt: Date?
    
    @NSManaged
    var name: String
    
    @NSManaged
    var friends: Set<User>
    
    private lazy var _objectID: ObjectID = {
        return ObjectID(string: self.remoteID)
    }()
    
    var createdAt: Date {
        return _objectID.toDate()
    }
    
    /// The GraphQL ID of the object.
    /// !!!: This is only computed in this case becuase we're not testing against
    /// a live back-end
    var id: String {
        return GraphQLID.encode(type: "User", id: remoteID)!
    }
    
    override func awakeFromInsert() {
        let objectID = ObjectID.generator.next()
        remoteID = objectID.toString()
    }
}
