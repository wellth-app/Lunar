import Quick
import Nimble
import Apollo
import StarWarsAPI

@testable
import Lunar


final class LunarCacheImplmentationSpec: QuickSpec {
    override func spec() {
        let cacheURL = URL.temporaryDirectoryURL()
        let query = HeroNameQuery()
        
        var subject: LunarCache!
        var apolloStore: ApolloStore!
        var networkTransport: NetworkTransport!
        var apolloClient: ApolloClient!
        
        describe("LunarCache implementation") {
            beforeEach {
                subject = try! LunarCache(
                    cacheURL: cacheURL,
                    useMainQueueContext: true
                )
                
                apolloStore = ApolloStore(cache: subject)
                
                networkTransport = MockNetworkTransport(body: [
                    "data": [
                        "hero": [
                            "name": "Luke Skywalker",
                            "__typename": "Human"
                        ]
                    ]
                ])
                
                apolloClient = ApolloClient(
                    networkTransport: networkTransport,
                    store: apolloStore
                )
            }
            
            afterEach {
                try! subject.purge()
            }
            
            context("persistence") {
                var newSubject: LunarCache!
                var newStore: ApolloStore!
                var newClient: ApolloClient!
                
                beforeEach {
                    waitUntil { done in
                        /// Ensure the data is cached before creating a new one.
                        apolloClient.fetch(
                            query: query,
                            cachePolicy: .fetchIgnoringCacheData,
                            resultHandler: { _ in done() }
                        )
                    }
                    
                    newSubject = try! LunarCache(
                        cacheURL: cacheURL,
                        useMainQueueContext: true
                    )
                    
                    newStore = ApolloStore(cache: newSubject)
                    newClient = ApolloClient(
                        networkTransport: networkTransport,
                        store: newStore
                    )
                }
                
                afterEach {
                    try! newSubject.purge()
                }
            
                it("can fetch a query from a new cache") {
                    var queryResult: GraphQLResult<HeroNameQuery.Data>? = nil
                    
                    waitUntil { done in
                        newClient.fetch(query: query, cachePolicy: .returnCacheDataDontFetch) { result, error in
                            queryResult = result
                            done()
                        }
                    }
                    
                    expect(queryResult).toNot(beNil())
                    expect(queryResult?.data?.hero?.name).to(equal("Luke Skywalker"))
                    expect(queryResult?.data?.hero?.__typename).to(equal("Human"))
                }
            }
        }
    }
}
