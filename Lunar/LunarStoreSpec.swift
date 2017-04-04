import Quick
import Nimble
import CoreDataStack
import JSONMapping
import Apollo

@testable
import Lunar


final class LunarStoreSpec: QuickSpec {
    override func spec() {
        let bundle = Bundle(for: User.self)
        let dataStack = CoreDataStack(modelName: "Model", bundle: bundle, storeType: .inMemory)
        let managedObjectContext = dataStack.mainContext
        
        let dateFormatter: DateFormatter = {
            let formatter = DateFormatter()
            formatter.dateFormat = "YYYY-MM-ddThh:mm:ss.SSSX"
            return formatter
        }()
        
        afterEach {
            managedObjectContext.reset()
        }
        
        describe("Lunar Store") {
            var subject: LunarStore!
            
            it("can merge records into a context") {
                subject = LunarStore(context: managedObjectContext)
                
                let recordSet: RecordSet = [
                    GraphQLID.encode(type: "User", id: "caa8883084d514d44d412c7a")!:  [
                        "_id": "caa8883084d514d44d412c7a",
                        "archivedAt": NSNull(),
                        "updatedAt": "2016-09-22T22:41:31.330Z",
                        "name": "Justin"
                    ],
                    GraphQLID.encode(type: "User", id: "d144c584e72faa3d322440e2")!: [
                        "_id": "d144c584e72faa3d322440e2",
                        "archivedAt": NSNull(),
                        "updatedAt": "2016-10-04T22:02:29.355Z",
                        "name": "Paige"
                    ]
                ]
                
                do {
                    let changes = try subject
                        .merge(records: recordSet)
                        .await()
                    
                    expect(changes.count).to(equal(2))
                    
                    let records = try subject
                        .loadRecords(forKeys: Array(changes))
                        .await()
                    
                    expect(records.count).to(equal(2))
                    
                    let archivedDates: [Date] = records
                        .flatMap { $0 }
                        .flatMap { $0.fields["archivedAt"] as? String }
                        .flatMap { dateFormatter.date(from: $0) }
                    
                    expect(archivedDates.count).to(equal(2))
                } catch {
                    fail()
                }
            }
            
            it("loads no records from an empty context") {
                subject = LunarStore(context: managedObjectContext)
            }
            
            describe("In a populated context") {
                let id = GraphQLID.encode(type: "User", id: "d144c584e72faa3d322440e2")!
                let json: Apollo.JSONObject = [
                    "_id": "d144c584e72faa3d322440e2",
                    "archivedAt": NSNull(),
                    "updatedAt": "2016-10-04T22:02:29.355Z",
                    "name": "Paige"
                ]
                
                let recordSet: RecordSet = [id: json]
                
                beforeEach {
                    subject = LunarStore(context: managedObjectContext)
                    
                    do {
                        let _ = try subject.merge(records: recordSet).await()
                    } catch {
                        fail()
                        fatalError()
                    }
                }
                
                
                it("can load records from a context") {
                    let cacheKeys: [CacheKey] = [
                        id
                    ]
                    
                    do {
                        let result = try subject
                            .loadRecords(forKeys: cacheKeys)
                            .await()
                        
                        expect(result.count).to(equal(1))
                    } catch {
                        fail()
                    }
                }
            }
        }
    }
}
