# Lunar
An addition to Apollo for persistent data storage using CoreData.

Lunar provides an implementation of the `NormalizedCache` protocol in [Apollo](https://github.com/apollographql/apollo-ios) that uses CoreData for persistent storage.

### Usage
Lunar is meant to serve as a piece of the Apollo stack, connecting your app to a hands-off CoreData persistent storage layer:
```
let dataStack = /// Set up your core data stack
let context: NSManagedObjectContext = /// get a context from your stack
/// Optional
let dateFormatter: JSONDateFormatter = /// Create a formatter for serializing dates to and from CoreData objects.

let apollo = ApolloClient(
  networkTransport: MyNetworkTransport(),
  store: LunarStore(
    managedObjectContext: context,
    dateFormatter: dateFormatter
  )
)
```
