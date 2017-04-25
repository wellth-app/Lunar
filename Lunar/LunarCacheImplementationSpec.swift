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
        
        var subject: NormalizedCache!
        var apolloStore: ApolloStore!
        var networkTransport: NetworkTransport!
        var apolloClient: ApolloClient!
        
        beforeEach {
            subject = try! LunarCache(
                cacheURL: cacheURL,
                useMainQueueContext: true
            )
            
            apolloStore = ApolloStore(cache: subject)
            
            networkTransport = MockNetworkTransport(responseBody: [
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
        
        context("persistence") {
            var newSubject: NormalizedCache!
            var newStore: ApolloStore!
            var newClient: ApolloClient!
            
            beforeEach {
                
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
        
            it("can fetch a query from a new cache") {
                var queryResult: GraphQLResult<HeroNameQuery.Data>? = nil
                
                waitUntil { done in
                    /// Ensure the data is cached by the client before creating a
                    /// new one.
                    apolloClient.fetch(query: query, cachePolicy: .fetchIgnoringCacheData) { firstResult, _ in
                        newClient.fetch(query: query, cachePolicy: .returnCacheDataDontFetch) { result, error in
                            queryResult = result
                            done()
                        }
                    }
                    
                }
                
                expect(queryResult).toNot(beNil())
                expect(queryResult?.data?.hero?.name).to(equal("Luke Skywalker"))
                expect(queryResult?.data?.hero?.__typename).to(equal("Human"))
            }
        }
    }
}
