import Quick
import Nimble
import CoreData
import Apollo

@testable
import Lunar


final class LunarCacheSpec: QuickSpec {
    override func spec() {
        describe("Lunar Cache") {
            var subject: LunarCache!
            
            let dateFormatter: DateFormatter = {
                let formatter = DateFormatter()
                formatter.locale = Locale(identifier: "en_US")
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSX"
                return formatter
            }()
            
            beforeEach {
                subject = try! LunarCache(useMainQueueContext: true)
                try! subject.purge()
            }
            
            it("can merge records") {
                let archivedAtString = dateFormatter.string(from: Date())
                
                let recordSet: RecordSet = [
                    "caa8883084d514d44d412c7a":  [
                        "_id": "caa8883084d514d44d412c7a",
                        "archivedAt": archivedAtString,
                        "updatedAt": "2016-09-22T22:41:31.330Z",
                        "name": "Justin"
                    ],
                    "d144c584e72faa3d322440e2": [
                        "_id": "d144c584e72faa3d322440e2",
                        "archivedAt": archivedAtString,
                        "updatedAt": "2016-10-04T22:02:29.355Z",
                        "name": "Paige"
                    ]
                ]
                
                do {
                    var error: Error? = nil
                    let changes = try subject
                        .merge(records: recordSet)
                        .catch { mergeError in
                            error = mergeError
                        }
                        .await()
                    
                    expect(error).to(beNil())
                    
                    /// Expect there to be 8 changed fields, 4 for each user.
                    expect(changes.count).to(equal(8))
                } catch {
                    fail()
                }
            }
            
            it("loads no records from an empty context") {
                let keys: [CacheKey] = [
                    "caa8883084d514d44d412c7a",
                    "d144c584e72faa3d322440e2"
                ]
                
                do {
                    /// Filter out the nil records for the sake of the test
                    let result = try subject
                        .loadRecords(forKeys: keys)
                        .await()
                        .filter { $0 != nil }
                    
                    expect(result.count).to(equal(0))
                } catch {
                    fail()
                }
            }
            
            it("stores relationships in seperate objects") {
                let recordSet: RecordSet = [
                    "caa8883084d514d44d412c7a":  [
                        "_id": "caa8883084d514d44d412c7a",
                        "archivedAt": NSNull(),
                        "updatedAt": "2016-09-22T22:41:31.330Z",
                        "name": "Justin",
                        "significantOther": Reference(key: "d144c584e72faa3d322440e2")
                    ],
                    "d144c584e72faa3d322440e2": [
                        "_id": "d144c584e72faa3d322440e2",
                        "archivedAt": NSNull(),
                        "updatedAt": "2016-10-04T22:02:29.355Z",
                        "name": "Paige",
                        "significantOther": [
                            "_id": "caa8883084d514d44d412c7a",
                            "archivedAt": NSNull(),
                            "updatedAt": "2016-09-22T22:41:31.330Z",
                            "name": "Justin",
                            "significantOther": Reference(key: "d144c584e72faa3d322440e2")
                        ],
                        "friends": [
                            Reference(key: "1234"),
                            Reference(key: "5678")
                        ]
                    ]
                ]
                
                do {
                    let result = try subject
                        .merge(records: recordSet)
                        .await()
                    
                    print(result)
                } catch {
                    fail()
                }
            }
            
            context("In a populated context") {
                let id = "d144c584e72faa3d322440e2"
                let json: Apollo.JSONObject = [
                    "_id": "d144c584e72faa3d322440e2",
                    "archivedAt": NSNull(),
                    "updatedAt": "2016-10-04T22:02:29.355Z",
                    "name": "Paige"
                ]
                
                let recordSet: RecordSet = [id: json]
                
                beforeEach {
                    do {
                        /// Insert "Paige" into the cache for each test.
                        _ = try subject
                            .merge(records: recordSet)
                            .await()
                    } catch {
                        fail()
                    }
                }
                
                it("can load records") {
                    do {
                        let result = try subject
                            .loadRecords(forKeys: [id])
                            .await()
                        
                        expect(result.count).to(equal(1))
                    } catch {
                        fail()
                    }
                }
                
                it("can tell you which fields have changed") {
                    let updateRecordSet: RecordSet = [
                        id: [
                            "archivedAt": dateFormatter.string(from: Date())
                        ]
                    ]
                    
                    do {
                        let result = try subject
                            .merge(records: updateRecordSet)
                            .await()
                        
                        let changedCacheKey = [id, "archivedAt"].joined(separator: ".")
                        expect(result).to(contain([changedCacheKey]))
                    } catch {
                        fail()
                    }
                }
                
                it("can purge all existing records") {
                    do {
                        let result = try subject
                            .loadRecords(forKeys: [id])
                            .await()
                        
                        expect(result.count).to(equal(1))
                        
                        try subject.purge()
                        
                        let records = try subject
                            .loadRecords(forKeys: [id])
                            .await()
                            .filter { $0 != nil }
                        
                        expect(records).to(beEmpty())
                    } catch {
                        fail()
                    }
                }
            }
        }
    }
}
