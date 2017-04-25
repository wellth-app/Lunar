@testable
import Apollo


final class MockNetworkTransport: NetworkTransport {
    let responseBody: JSONObject
    
    init(responseBody: JSONObject) {
        self.responseBody = responseBody
    }
    
    func send<Operation>(operation: Operation, completionHandler: @escaping (GraphQLResponse<Operation>?, Error?) -> Void) -> Cancellable where Operation : GraphQLOperation {
        let body = responseBody
        DispatchQueue.global().async {
            completionHandler(
                GraphQLResponse(
                    operation: operation,
                    body: body
                ),
                nil
            )
        }
        
        return MockCancellable()
    }
}

private final class MockCancellable: Cancellable {
    func cancel() { }
}
